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

// The project's default compute service account doesn't exist; run as the App Engine one.
exports.lemonSqueezyWebhook = functions
  .runWith({ serviceAccount: 'rocis-todo@appspot.gserviceaccount.com' })
  .https.onRequest(async (req, res) => {
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
    const ref = db.collection('users').doc(String(userId));

    // Subscription and lifetime state are kept separately so that one kind of
    // event (e.g. an order or a renewal invoice) never revokes the other.
    let update;
    if (data.type === 'subscriptions') {
      update = {
        ls_subscription_active: subscriptionGrantsPro(attributes),
        subscription_status: attributes.status || 'unknown',
        subscription_id: String(data.id),
        subscription_ends_at: attributes.ends_at || null,
        subscription_trial_ends_at: attributes.trial_ends_at || null,
      };
    } else if (data.type === 'orders' && isLifetimeOrder(attributes)) {
      update = { ls_lifetime: attributes.status === 'paid' };
    } else {
      // Subscription orders, invoices etc. carry no entitlement change.
      res.status(200).send('OK: Event ignored.');
      return;
    }

    const isPremium = await db.runTransaction(async (tx) => {
      const doc = (await tx.get(ref)).data() || {};
      const merged = { ...doc, ...update };
      const premium = merged.ls_subscription_active === true || merged.ls_lifetime === true;
      tx.set(ref, {
        ...update,
        is_premium: premium,
        last_billing_sync: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      return premium;
    });

    console.log(`"${meta.event_name}" (${data.type}, ${attributes.status}) -> is_premium=${isPremium} for ${userId}`);
    res.status(200).send('Webhook processed successfully.');
  } catch (error) {
    console.error('Error processing Lemon Squeezy webhook:', error);
    res.status(500).send('Internal Server Error');
  }
});

module.exports._test = { subscriptionGrantsPro, isLifetimeOrder };
