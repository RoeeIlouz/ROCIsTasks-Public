const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
const crypto = require('crypto');

admin.initializeApp();
const db = admin.firestore();

// Subscription statuses that keep Pro. "cancelled" keeps it until ends_at (it was
// paid for); past_due keeps it while Lemon Squeezy retries the payment.
const ACTIVE_STATUSES = new Set(['on_trial', 'active', 'past_due']);

/** Whether a Lemon Squeezy subscription object grants Pro right now. */
function subscriptionGrantsPro(attributes) {
  const status = attributes.status;
  if (ACTIVE_STATUSES.has(status)) return true;
  if (status === 'cancelled' && attributes.ends_at) {
    return new Date(attributes.ends_at).getTime() > Date.now();
  }
  return false;
}

/**
 * Whether an order is the one-time lifetime purchase. Set LEMONSQUEEZY_LIFETIME_VARIANT_IDS
 * (comma-separated variant ids) to be exact; otherwise the product/variant name must
 * contain "lifetime".
 */
function isLifetimeOrder(attributes) {
  const item = attributes.first_order_item || {};
  const ids = (process.env.LEMONSQUEEZY_LIFETIME_VARIANT_IDS || '')
    .split(',').map((s) => s.trim()).filter(Boolean);
  if (ids.length > 0) return ids.includes(String(item.variant_id));
  const name = `${item.product_name || ''} ${item.variant_name || ''}`.toLowerCase();
  return name.includes('lifetime');
}

/**
 * Merges [update] into users/{uid} and recomputes is_premium from every source:
 * Lemon Squeezy subscription, Lemon Squeezy lifetime and RevenueCat (mobile).
 * Only the server writes these fields (see firestore.rules).
 */
async function applyEntitlements(uid, update, isStale = () => false) {
  const ref = db.collection('users').doc(uid);
  return db.runTransaction(async (tx) => {
    const current = (await tx.get(ref)).data() || {};
    if (isStale(current)) return current.is_premium === true;
    const merged = { ...current, ...update };
    const premium = merged.ls_subscription_active === true ||
      merged.ls_lifetime === true ||
      merged.rc_premium === true;
    tx.set(ref, {
      ...update,
      is_premium: premium,
      last_billing_sync: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return premium;
  });
}

/**
 * Lemon Squeezy doesn't guarantee delivery order, so a retried older event can
 * arrive after a newer one. It's stale when its updated_at is before the one
 * already recorded.
 */
function subscriptionEventIsStale(recordedUpdatedAt, eventUpdatedAt) {
  if (!recordedUpdatedAt || !eventUpdatedAt) return false;
  return new Date(eventUpdatedAt).getTime() < new Date(recordedUpdatedAt).getTime();
}

const RC_PROJECT_ID = 'proj562f5a11';

/**
 * Asks RevenueCat (API v2, read-only customers key) whether [uid] (the RevenueCat app
 * user id) has an active entitlement, and records it. The project's only entitlement
 * is Pro; set REVENUECAT_ENTITLEMENT_ID (entl...) to require a specific one.
 */
async function refreshRevenueCat(uid) {
  const key = process.env.REVENUECAT_SECRET_KEY;
  if (!key) throw new Error('REVENUECAT_SECRET_KEY is not configured.');
  const response = await fetch(
    `https://api.revenuecat.com/v2/projects/${RC_PROJECT_ID}/customers/` +
      `${encodeURIComponent(uid)}/active_entitlements?limit=20`,
    { headers: { Authorization: `Bearer ${key}`, Accept: 'application/json' } },
  );
  let items = [];
  if (response.status !== 404) { // 404: never used RevenueCat, so no entitlement.
    if (!response.ok) throw new Error(`RevenueCat ${response.status} for ${uid}`);
    items = (await response.json()).items || [];
  }
  const wanted = process.env.REVENUECAT_ENTITLEMENT_ID;
  const now = Date.now();
  const active = items.filter((e) =>
    (!wanted || e.entitlement_id === wanted) && (e.expires_at == null || e.expires_at > now));
  const expiresAt = active.some((e) => e.expires_at == null) ? null
    : active.reduce((max, e) => Math.max(max, e.expires_at), 0) || null;
  console.log(`RevenueCat entitlement for ${uid}: ${active.length > 0}`);
  return applyEntitlements(uid, {
    rc_premium: active.length > 0,
    rc_expires_at: expiresAt ? new Date(expiresAt).toISOString() : null,
  });
}

// The project's default compute service account doesn't exist; run as the App Engine one.
// Secrets come from Secret Manager (firebase functions:secrets:set), exposed as env vars.
const runOptions = {
  serviceAccount: 'rocis-todo@appspot.gserviceaccount.com',
  secrets: ['LEMONSQUEEZY_SECRET', 'REVENUECAT_SECRET_KEY', 'REVENUECAT_WEBHOOK_AUTH'],
};

exports.lemonSqueezyWebhook = functions.runWith(runOptions).https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }

  const webhookSecret = process.env.LEMONSQUEEZY_SECRET;
  if (!webhookSecret) {
    console.error('LEMONSQUEEZY_SECRET is not configured.');
    res.status(500).send('Internal Server Error: Secret not configured.');
    return;
  }

  const signature = req.headers['x-signature'];
  if (!signature) {
    res.status(401).send('Unauthorized: Missing signature.');
    return;
  }
  try {
    const digest = crypto.createHmac('sha256', webhookSecret).update(req.rawBody).digest('hex');
    const a = Buffer.from(signature, 'utf-8');
    const b = Buffer.from(digest, 'utf-8');
    if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) {
      res.status(401).send('Unauthorized: Invalid signature.');
      return;
    }
  } catch (err) {
    console.error('Error verifying webhook signature:', err);
    res.status(401).send('Unauthorized: Signature verification error.');
    return;
  }

  try {
    const { meta, data } = req.body || {};
    if (!meta || !data || !data.attributes) {
      res.status(400).send('Bad Request: Invalid payload structure.');
      return;
    }
    const userId = meta.custom_data ? meta.custom_data.user_id : null;
    if (!userId) {
      res.status(200).send('OK: No user_id provided, ignoring.');
      return;
    }
    const attributes = data.attributes;

    // Subscription and lifetime state are kept separately so that one kind of
    // event (e.g. an order or a renewal invoice) never revokes the other.
    let update;
    let isStale;
    if (data.type === 'subscriptions') {
      isStale = (current) =>
        subscriptionEventIsStale(current.ls_subscription_updated_at, attributes.updated_at);
      update = {
        ls_subscription_active: subscriptionGrantsPro(attributes),
        subscription_status: attributes.status || 'unknown',
        subscription_id: String(data.id),
        subscription_ends_at: attributes.ends_at || null,
        subscription_trial_ends_at: attributes.trial_ends_at || null,
        ls_subscription_updated_at: attributes.updated_at || null,
      };
    } else if (data.type === 'orders' && isLifetimeOrder(attributes)) {
      update = { ls_lifetime: attributes.status === 'paid' };
    } else {
      // Subscription orders, invoices etc. carry no entitlement change.
      res.status(200).send('OK: Event ignored.');
      return;
    }

    const isPremium = await applyEntitlements(String(userId), update, isStale);

    console.log(`"${meta.event_name}" (${data.type}, ${attributes.status}) -> is_premium=${isPremium} for ${userId}`);
    res.status(200).send('Webhook processed successfully.');
  } catch (error) {
    console.error('Error processing Lemon Squeezy webhook:', error);
    res.status(500).send('Internal Server Error');
  }
});

/**
 * RevenueCat webhook (Authorization header must equal REVENUECAT_WEBHOOK_AUTH). The
 * payload only says which user changed; the entitlement is re-read from RevenueCat.
 */
exports.revenueCatWebhook = functions.runWith(runOptions).https.onRequest(async (req, res) => {
  const auth = process.env.REVENUECAT_WEBHOOK_AUTH;
  const given = req.headers.authorization || '';
  if (!auth || given.length !== auth.length ||
      !crypto.timingSafeEqual(Buffer.from(given), Buffer.from(auth))) {
    res.status(401).send('Unauthorized');
    return;
  }
  const event = (req.body && req.body.event) || {};
  if (event.type === 'TEST') {
    res.status(200).send('OK: test event');
    return;
  }
  const ids = new Set([event.app_user_id, event.original_app_user_id, ...(event.aliases || [])]
    .filter((id) => id && !String(id).startsWith('$RCAnonymousID')));
  try {
    for (const id of ids) {
      const premium = await refreshRevenueCat(String(id));
      console.log(`RevenueCat "${event.type}" -> is_premium=${premium} for ${id}`);
    }
    res.status(200).send('OK');
  } catch (error) {
    console.error('Error processing RevenueCat webhook:', error);
    res.status(500).send('Internal Server Error');
  }
});

/**
 * Called by the app (Authorization: Bearer <Firebase ID token>) after sign-in or a
 * purchase, so existing and just-purchased subscriptions are recorded server-side.
 */
exports.syncPremium = functions.runWith(runOptions).https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Headers', 'Authorization');
    res.status(204).send('');
    return;
  }
  const match = /^Bearer (.+)$/.exec(req.headers.authorization || '');
  if (!match) {
    res.status(401).send('Unauthorized');
    return;
  }
  try {
    const { uid } = await admin.auth().verifyIdToken(match[1]);
    const premium = await refreshRevenueCat(uid);
    res.status(200).json({ is_premium: premium });
  } catch (error) {
    console.error('syncPremium failed:', error);
    res.status(error.code && String(error.code).startsWith('auth/') ? 401 : 500).send('Error');
  }
});

module.exports._test = { subscriptionGrantsPro, isLifetimeOrder, subscriptionEventIsStale };
