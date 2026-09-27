const test = require('node:test');
const assert = require('node:assert/strict');

const { subscriptionGrantsPro, isLifetimeOrder, subscriptionEventIsStale } =
  require('../index.js')._test;

test('an older subscription event than the recorded one is stale', () => {
  assert.equal(subscriptionEventIsStale('2026-09-27T10:00:00Z', '2026-09-27T09:59:59Z'), true);
  assert.equal(subscriptionEventIsStale('2026-09-27T10:00:00Z', '2026-09-27T10:00:00Z'), false);
  assert.equal(subscriptionEventIsStale('2026-09-27T10:00:00Z', '2026-09-27T10:00:01Z'), false);
});

test('without both timestamps nothing is stale', () => {
  assert.equal(subscriptionEventIsStale(null, '2026-09-27T10:00:00Z'), false);
  assert.equal(subscriptionEventIsStale('2026-09-27T10:00:00Z', null), false);
});

test('cancelled subscriptions keep Pro until ends_at', () => {
  const future = new Date(Date.now() + 86400000).toISOString();
  const past = new Date(Date.now() - 86400000).toISOString();
  assert.equal(subscriptionGrantsPro({ status: 'active' }), true);
  assert.equal(subscriptionGrantsPro({ status: 'cancelled', ends_at: future }), true);
  assert.equal(subscriptionGrantsPro({ status: 'cancelled', ends_at: past }), false);
  assert.equal(subscriptionGrantsPro({ status: 'expired' }), false);
});

test('lifetime orders are recognised by name without configured variant ids', () => {
  assert.equal(isLifetimeOrder({ first_order_item: { variant_name: 'Lifetime' } }), true);
  assert.equal(isLifetimeOrder({ first_order_item: { variant_name: 'Yearly' } }), false);
});
