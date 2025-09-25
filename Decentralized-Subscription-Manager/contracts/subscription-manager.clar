;; Decentralized Subscription Manager
;; Advanced recurring payment platform for services in STX/sBTC
;; Version 2.0 - Enhanced with comprehensive features

;; Contract constants
(define-constant contract-owner tx-sender)
(define-constant platform-fee-rate u250) ;; 2.5% = 250/10000
(define-constant max-service-name-length u64)
(define-constant max-description-length u256)
(define-constant min-subscription-interval u144) ;; ~1 day in blocks
(define-constant max-subscription-interval u52560) ;; ~1 year in blocks

;; Error constants
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-already-exists (err u104))
(define-constant err-subscription-inactive (err u105))
(define-constant err-invalid-interval (err u106))
(define-constant err-invalid-price (err u107))
(define-constant err-service-inactive (err u108))
(define-constant err-payment-not-due (err u109))
(define-constant err-subscription-expired (err u110))

;; Data structures
(define-map subscriptions
  { subscriber: principal, service-id: uint }
  {
    provider: principal,
    amount: uint,
    interval: uint,
    last-payment: uint,
    next-payment: uint,
    active: bool,
    created-at: uint,
    total-payments: uint,
    grace-period: uint
  })

(define-map services
  uint
  {
    provider: principal,
    name: (string-ascii 64),
    description: (string-ascii 256),
    price: uint,
    interval: uint,
    active: bool,
    created-at: uint,
    subscriber-count: uint,
    total-revenue: uint,
    category: (string-ascii 32)
  })

(define-map service-categories
  (string-ascii 32)
  { count: uint, active: bool })

(define-map provider-stats
  principal
  {
    services-created: uint,
    total-subscribers: uint,
    total-revenue: uint,
    reputation-score: uint
  })

(define-map platform-stats
  uint
  {
    total-services: uint,
    total-subscriptions: uint,
    total-volume: uint,
    total-fees-collected: uint
  })

;; Data variables
(define-data-var next-service-id uint u1)
(define-data-var platform-fee-recipient principal contract-owner)
(define-data-var contract-paused bool false)
(define-data-var total-platform-fees uint u0)
