# Decentralized Subscription Manager

A blockchain-based recurring payment platform that enables users to subscribe to services with automated STX payments.

## Features

- **Service Registration**: Providers can list services with custom pricing and billing intervals
- **Automated Payments**: Recurring payments processed on-chain based on block height
- **Subscription Management**: Users can subscribe, monitor, and cancel subscriptions
- **Transparent Billing**: All payment history recorded on-chain
- **No Intermediaries**: Direct payments between subscribers and service providers

## Contract Functions

### Public Functions
- `create-service()`: Register a new service offering
- `subscribe-to-service()`: Subscribe to a service with initial payment
- `process-payment()`: Process recurring subscription payment
- `cancel-subscription()`: Cancel an active subscription

### Read-Only Functions
- `get-subscription()`: Retrieve subscription details
- `get-service()`: Get service information

## Usage

Service providers create offerings, users subscribe with automatic recurring payments, and the system handles payment processing based on blockchain timing.

## Payment Model

Payments are processed in STX with intervals measured in blocks, providing predictable and transparent billing cycles.