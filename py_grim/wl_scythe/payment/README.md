# Scythe Payment Processing System

Complete Stripe integration for subscriptions, billing, commission tracking, and multi-currency support.

## Features

- **BillingManager**: Complete subscription management with tier-based pricing
- **Stripe Connect**: Vendor payment processing and commission tracking
- **Webhook Handler**: Real-time payment event processing
- **Refund Manager**: Comprehensive refund and chargeback handling
- **Multi-Currency**: Support for 10+ currencies with real-time conversion
- **Overage Billing**: Automatic calculation and processing of usage overages
- **Automated Payouts**: Scheduled vendor payments with commission calculation

## Quick Start

### Installation

```bash
cd scythe/payment
pip install -r requirements.txt
```

### Configuration

Set environment variables:

```bash
export STRIPE_SECRET_KEY="sk_test_..."
export STRIPE_CONNECT_CLIENT_ID="ca_..."
export STRIPE_WEBHOOK_SECRET="whsec_..."
export STRIPE_PUBLISHABLE_KEY="pk_test_..."
```

### Database Setup

The payment system requires additional database tables:

```sql
-- Stripe customers
CREATE TABLE stripe_customers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    stripe_customer_id TEXT UNIQUE NOT NULL,
    email TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Subscriptions
CREATE TABLE subscriptions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    tier TEXT NOT NULL,
    billing_cycle TEXT NOT NULL,
    amount INTEGER NOT NULL,
    currency TEXT NOT NULL,
    status TEXT DEFAULT 'active',
    stripe_subscription_id TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Invoices
CREATE TABLE invoices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    stripe_invoice_id TEXT UNIQUE,
    amount DECIMAL(10,2) NOT NULL,
    currency TEXT NOT NULL,
    status TEXT DEFAULT 'draft',
    type TEXT DEFAULT 'subscription',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    paid_at TIMESTAMP
);

-- Vendor transfers
CREATE TABLE vendor_transfers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    vendor_id INTEGER NOT NULL,
    stripe_transfer_id TEXT UNIQUE,
    payment_intent_id TEXT,
    amount DECIMAL(10,2) NOT NULL,
    currency TEXT NOT NULL,
    commission_rate DECIMAL(5,2) NOT NULL,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Vendor payouts
CREATE TABLE vendor_payouts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    vendor_id INTEGER NOT NULL,
    stripe_payout_id TEXT UNIQUE,
    amount DECIMAL(10,2) NOT NULL,
    currency TEXT NOT NULL,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    paid_at TIMESTAMP
);

-- Refunds
CREATE TABLE refunds (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT,
    stripe_refund_id TEXT UNIQUE,
    payment_intent_id TEXT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    currency TEXT NOT NULL,
    reason TEXT NOT NULL,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Chargebacks
CREATE TABLE chargebacks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT,
    stripe_dispute_id TEXT UNIQUE,
    payment_intent_id TEXT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    currency TEXT NOT NULL,
    reason TEXT NOT NULL,
    status TEXT DEFAULT 'needs_response',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## API Endpoints

### Subscriptions

- `POST /scythe/payment/subscriptions` - Create subscription
- `DELETE /scythe/payment/subscriptions/<id>` - Cancel subscription
- `GET /scythe/payment/subscriptions/status` - Get subscription status

### Vendor Connect

- `POST /scythe/payment/vendor/connect-account` - Create Connect account
- `GET /scythe/payment/vendor/<id>/login-link` - Get vendor login link
- `POST /scythe/payment/vendor/<id>/payout` - Process vendor payout

### Refunds

- `POST /scythe/payment/refunds` - Create refund
- `GET /scythe/payment/refunds/<id>` - Get refund details

### Currency

- `GET /scythe/payment/currencies` - Get supported currencies
- `POST /scythe/payment/currencies/convert` - Convert currency

### Webhooks

- `POST /scythe/payment/webhook` - Handle Stripe webhooks

## Usage Examples

### Create Subscription

```python
from scythe.payment.billing_manager import BillingManager

billing = BillingManager("sk_test_...")
subscription = billing.create_subscription(
    user_id="user123",
    tier="PRO",
    billing_cycle="monthly"
)
```

### Process Vendor Payment

```python
from scythe.payment.stripe_connect import StripeConnectManager

connect = StripeConnectManager("sk_test_...", "ca_...")
transfer = connect.create_split_payment(
    payment_intent_id="pi_...",
    vendor_id=1,
    commission_rate=15.0
)
```

### Handle Webhook

```python
from scythe.payment.webhook_handler import StripeWebhookHandler

handler = StripeWebhookHandler("sk_test_...", "whsec_...")
result = handler.handle_webhook(payload, signature)
```

## Tier Pricing

| Tier | Monthly | Yearly | Features |
|------|---------|--------|----------|
| FREE | $0 | $0 | Basic features |
| PRO | $29.99 | $299.90 | Advanced features |
| MASTER | $99.99 | $999.90 | Premium features |
| REAPER | $199.99 | $1999.90 | Enterprise features |

## Overage Pricing

- Storage: $0.10 per GB
- API Calls: $0.001 per call
- Alerts: $0.01 per alert

## Supported Currencies

- USD, EUR, GBP, CAD, AUD, JPY, CHF, SEK, NOK, DKK

## Webhook Events

- `invoice.payment_succeeded`
- `invoice.payment_failed`
- `customer.subscription.created`
- `customer.subscription.updated`
- `customer.subscription.deleted`
- `payment_intent.succeeded`
- `payment_intent.payment_failed`
- `transfer.created`
- `transfer.failed`
- `payout.paid`
- `payout.failed`

## Error Handling

All payment operations include comprehensive error handling:

- Stripe API errors
- Network timeouts
- Invalid data validation
- Database transaction failures
- Webhook signature verification

## Security

- All API keys are stored securely
- Webhook signatures are verified
- PCI DSS compliant
- Encrypted data transmission
- Audit logging for all operations

## Testing

### Test Mode

Use Stripe test keys for development:

```bash
export STRIPE_SECRET_KEY="sk_test_..."
export STRIPE_PUBLISHABLE_KEY="pk_test_..."
```

### Test Cards

- Success: `4242424242424242`
- Decline: `4000000000000002`
- Insufficient funds: `4000000000009995`

## Monitoring

The system includes comprehensive logging and monitoring:

- Payment success/failure rates
- Refund statistics
- Chargeback tracking
- Vendor payout history
- Currency conversion rates

## Deployment

### Production Checklist

1. Set production Stripe keys
2. Configure webhook endpoints
3. Set up database backups
4. Configure monitoring alerts
5. Test all payment flows
6. Verify PCI compliance
7. Set up fraud detection
8. Configure automated payouts

### Environment Variables

```bash
# Required
STRIPE_SECRET_KEY=sk_live_...
STRIPE_CONNECT_CLIENT_ID=ca_...
STRIPE_WEBHOOK_SECRET=whsec_...

# Optional
STRIPE_PUBLISHABLE_KEY=pk_live_...
PAYMENT_LOG_LEVEL=INFO
PAYMENT_WEBHOOK_URL=https://api.scythe.com/webhook
```

## Support

For payment system support:

1. Check Stripe documentation
2. Review webhook logs
3. Verify API key permissions
4. Test with Stripe CLI
5. Contact development team 