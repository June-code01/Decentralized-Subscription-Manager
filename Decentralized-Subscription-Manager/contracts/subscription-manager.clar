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


(define-public (create-service 
  (name (string-ascii 64))
  (description (string-ascii 256))
  (price uint)
  (interval uint)
  (category (string-ascii 32)))
  (let ((service-id (var-get next-service-id))
        (caller tx-sender))
    
    ;; Validation
    (asserts! (not (var-get contract-paused)) err-unauthorized)
    (asserts! (> price u0) err-invalid-price)
    (asserts! (and (>= interval min-subscription-interval) 
                   (<= interval max-subscription-interval)) err-invalid-interval)
    (asserts! (> (len name) u0) err-invalid-price)
    
    ;; Create service
    (map-set services service-id {
      provider: caller,
      name: name,
      description: description,
      price: price,
      interval: interval,
      active: true,
      created-at: block-height,
      subscriber-count: u0,
      total-revenue: u0,
      category: category
    })
    
    ;; Update category
    (map-set service-categories category
      (match (map-get? service-categories category)
        existing-cat (merge existing-cat { count: (+ (get count existing-cat) u1) })
        { count: u1, active: true }))
    
    ;; Update provider stats
    (update-provider-stats caller u1 u0 u0)
    
    ;; Update next service ID
    (var-set next-service-id (+ service-id u1))
    
    ;; Update platform stats
    (update-platform-stats u1 u0 u0)
    
    (ok service-id)))

(define-public (update-service 
  (service-id uint)
  (name (string-ascii 64))
  (description (string-ascii 256))
  (price uint))
  (let ((caller tx-sender)
        (service (unwrap! (map-get? services service-id) err-not-found)))
    
    (asserts! (is-eq caller (get provider service)) err-unauthorized)
    (asserts! (> price u0) err-invalid-price)
    (asserts! (> (len name) u0) err-invalid-price)
    
    (ok (map-set services service-id
      (merge service {
        name: name,
        description: description,
        price: price
      })))))

(define-public (toggle-service-status (service-id uint))
  (let ((caller tx-sender)
        (service (unwrap! (map-get? services service-id) err-not-found)))
    
    (asserts! (is-eq caller (get provider service)) err-unauthorized)
    
    (ok (map-set services service-id
      (merge service {
        active: (not (get active service))
      })))))

(define-public (subscribe-to-service (service-id uint) (grace-period uint))
  (let ((caller tx-sender)
        (service (unwrap! (map-get? services service-id) err-not-found))
        (subscription-key {subscriber: caller, service-id: service-id})
        (platform-fee (/ (* (get price service) platform-fee-rate) u10000))
        (provider-amount (- (get price service) platform-fee)))
    
    ;; Validation
    (asserts! (not (var-get contract-paused)) err-unauthorized)
    (asserts! (get active service) err-service-inactive)
    (asserts! (is-none (map-get? subscriptions subscription-key)) err-already-exists)
    (asserts! (>= (stx-get-balance caller) (get price service)) err-insufficient-balance)
    (asserts! (<= grace-period (get interval service)) err-invalid-interval)
    
    ;; Process payment
    (try! (stx-transfer? provider-amount caller (get provider service)))
    (try! (stx-transfer? platform-fee caller (var-get platform-fee-recipient)))
    
    ;; Create subscription
    (map-set subscriptions subscription-key {
      provider: (get provider service),
      amount: (get price service),
      interval: (get interval service),
      last-payment: block-height,
      next-payment: (+ block-height (get interval service)),
      active: true,
      created-at: block-height,
      total-payments: u1,
      grace-period: grace-period
    })
    
    ;; Update service stats
    (map-set services service-id
      (merge service {
        subscriber-count: (+ (get subscriber-count service) u1),
        total-revenue: (+ (get total-revenue service) (get price service))
      }))
    
    ;; Update provider stats
    (update-provider-stats (get provider service) u0 u1 (get price service))
    
    ;; Update platform stats
    (update-platform-stats u0 u1 (get price service))
    (var-set total-platform-fees (+ (var-get total-platform-fees) platform-fee))
    
    (ok true)))

(define-public (cancel-subscription (service-id uint))
  (let ((caller tx-sender)
        (subscription-key {subscriber: caller, service-id: service-id})
        (subscription (unwrap! (map-get? subscriptions subscription-key) err-not-found))
        (service (unwrap! (map-get? services service-id) err-not-found)))
    
    ;; Update service subscriber count
    (map-set services service-id
      (merge service {
        subscriber-count: (- (get subscriber-count service) u1)
      }))
    
    ;; Update provider stats
    (update-provider-stats (get provider subscription) u0 u1 u0)
    
    ;; Remove subscription
    (ok (map-delete subscriptions subscription-key))))

(define-public (pause-subscription (service-id uint))
  (let ((caller tx-sender)
        (subscription-key {subscriber: caller, service-id: service-id})
        (subscription (unwrap! (map-get? subscriptions subscription-key) err-not-found)))
    
    (asserts! (get active subscription) err-subscription-inactive)
    
    (ok (map-set subscriptions subscription-key
      (merge subscription { active: false })))))

(define-public (resume-subscription (service-id uint))
  (let ((caller tx-sender)
        (subscription-key {subscriber: caller, service-id: service-id})
        (subscription (unwrap! (map-get? subscriptions subscription-key) err-not-found)))
    
    (asserts! (not (get active subscription)) err-already-exists)
    
    (ok (map-set subscriptions subscription-key
      (merge subscription { active: true })))))

(define-public (process-payment (subscriber principal) (service-id uint))
  (let ((subscription-key {subscriber: subscriber, service-id: service-id})
        (subscription (unwrap! (map-get? subscriptions subscription-key) err-not-found))
        (service (unwrap! (map-get? services service-id) err-not-found))
        (platform-fee (/ (* (get amount subscription) platform-fee-rate) u10000))
        (provider-amount (- (get amount subscription) platform-fee))
        (grace-deadline (+ (get next-payment subscription) (get grace-period subscription))))
    
    ;; Validation
    (asserts! (not (var-get contract-paused)) err-unauthorized)
    (asserts! (get active subscription) err-subscription-inactive)
    (asserts! (get active service) err-service-inactive)
    (asserts! (>= block-height (get next-payment subscription)) err-payment-not-due)
    (asserts! (<= block-height grace-deadline) err-subscription-expired)
    (asserts! (>= (stx-get-balance subscriber) (get amount subscription)) err-insufficient-balance)
    
    ;; Process payment
    (try! (stx-transfer? provider-amount subscriber (get provider subscription)))
    (try! (stx-transfer? platform-fee subscriber (var-get platform-fee-recipient)))
    
    ;; Update subscription
    (map-set subscriptions subscription-key
      (merge subscription {
        last-payment: block-height,
        next-payment: (+ block-height (get interval subscription)),
        total-payments: (+ (get total-payments subscription) u1)
      }))
    
    ;; Update service stats
    (map-set services service-id
      (merge service {
        total-revenue: (+ (get total-revenue service) (get amount subscription))
      }))
    
    ;; Update provider stats
    (update-provider-stats (get provider subscription) u0 u0 (get amount subscription))
    
    ;; Update platform stats
    (update-platform-stats u0 u0 (get amount subscription))
    (var-set total-platform-fees (+ (var-get total-platform-fees) platform-fee))
    
    (ok true)))

(define-public (batch-process-payments (subscribers-services (list 50 { subscriber: principal, service-id: uint })))
  (let ((results (map process-single-payment subscribers-services)))
    (ok results)))

(define-private (process-single-payment (sub-service { subscriber: principal, service-id: uint }))
  (process-payment (get subscriber sub-service) (get service-id sub-service)))

(define-public (withdraw-earnings (amount uint))
  (let ((caller tx-sender)
        (provider-earnings (get-provider-earnings caller)))
    
    (asserts! (>= provider-earnings amount) err-insufficient-balance)
    (asserts! (> amount u0) err-invalid-price)
    
    ;; This would require implementing an earnings tracking system
    ;; For now, returning success as a placeholder
    (ok true)))