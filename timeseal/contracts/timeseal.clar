;; Conditional Time-locked Payments
;; Allows users to lock funds that can only be released when both:
;; 1. A specific block height has been reached
;; 2. External conditions (such as oracle data) have been met

(define-data-var payment-id-nonce uint u0)

;; Constants for validation
(define-constant max-lock-blocks u52560) ;; ~1 year at 10 min blocks
(define-constant min-amount u1)
(define-constant max-amount u1000000000000) ;; 1 million STX

(define-map payments
  { payment-id: uint }
  {
    sender: principal,
    recipient: principal,
    amount: uint,
    unlock-height: uint,
    oracle-check: (string-ascii 128),
    threshold-value: uint,
    fulfilled: bool,
    canceled: bool
  }
)

;; Map of oracle values that can be set by authorized oracle providers
(define-map oracle-values
  { key: (string-ascii 128) }
  { value: uint, last-updated: uint }
)

;; List of authorized oracle providers
(define-map authorized-oracles
  { provider: principal }
  { authorized: bool }
)

;; Define contract owner (you should replace this with your actual deployment principal)
(define-constant contract-deployer tx-sender)

;; Validation functions
(define-private (is-valid-amount (amount uint))
  (and (>= amount min-amount) (<= amount max-amount))
)

(define-private (is-valid-lock-period (blocks uint))
  (and (>= blocks u1) (<= blocks max-lock-blocks))
)

(define-private (is-valid-oracle-key (key (string-ascii 128)))
  (> (len key) u0)
)

(define-private (is-valid-payment-id (payment-id uint))
  (< payment-id (var-get payment-id-nonce))
)

;; Create a new conditional payment
(define-public (create-payment (recipient principal) (amount uint) (blocks-locked uint) 
                              (oracle-check (string-ascii 128)) (threshold-value uint))
  (let
    ((payment-id (var-get payment-id-nonce))
     (unlock-height (+ block-height blocks-locked)))
    
    ;; Validate all parameters
    (asserts! (is-valid-amount amount) (err u1)) ;; Invalid amount
    (asserts! (is-valid-lock-period blocks-locked) (err u2)) ;; Invalid lock period
    (asserts! (is-valid-oracle-key oracle-check) (err u3)) ;; Invalid oracle key
    (asserts! (not (is-eq recipient tx-sender)) (err u4)) ;; Cannot send to self
    (asserts! (is-standard recipient) (err u5)) ;; Invalid recipient principal
    
    ;; Transfer STX from sender to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Create the payment entry with validated data
    (map-set payments
      { payment-id: payment-id }
      {
        sender: tx-sender,
        recipient: recipient,
        amount: amount,
        unlock-height: unlock-height,
        oracle-check: oracle-check,
        threshold-value: threshold-value,
        fulfilled: false,
        canceled: false
      }
    )
    
    ;; Increment payment ID counter
    (var-set payment-id-nonce (+ payment-id u1))
    
    (ok payment-id)
  )
)

;; Set an oracle value (only callable by authorized oracles)
(define-public (set-oracle-value (key (string-ascii 128)) (value uint))
  (begin
    ;; Validate oracle key
    (asserts! (is-valid-oracle-key key) (err u6)) ;; Invalid oracle key
    
    ;; Check that the caller is an authorized oracle
    (asserts! (is-authorized-oracle tx-sender) (err u7)) ;; Not authorized as oracle
    
    ;; Update the oracle value with validated data
    (map-set oracle-values
      { key: key }
      { value: value, last-updated: block-height }
    )
    
    (ok true)
  )
)

;; Private function to check if sender is an authorized oracle
(define-private (is-authorized-oracle (provider principal))
  (default-to false (get authorized (map-get? authorized-oracles { provider: provider })))
)

;; Add an authorized oracle (contract owner only)
(define-public (add-authorized-oracle (provider principal))
  (begin
    ;; Validate provider principal
    (asserts! (is-standard provider) (err u8)) ;; Invalid provider principal
    (asserts! (not (is-eq provider (as-contract tx-sender))) (err u9)) ;; Cannot authorize contract itself
    
    ;; Only contract owner can add oracles
    (asserts! (is-eq tx-sender (get-contract-owner)) (err u10)) ;; Not authorized
    
    ;; Add the authorized oracle with validated data
    (map-set authorized-oracles
      { provider: provider }
      { authorized: true }
    )
    
    (ok true)
  )
)

;; Private function to get contract owner
(define-private (get-contract-owner)
  contract-deployer
)

;; Claim a payment if conditions are met
(define-public (claim-payment (payment-id uint))
  (let
    ((payment-info (map-get? payments { payment-id: payment-id })))
    
    ;; Validate payment exists
    (asserts! (is-some payment-info) (err u11)) ;; Payment not found
    
    (let
      ((payment (unwrap-panic payment-info))
       (oracle-data (unwrap! (map-get? oracle-values { key: (get oracle-check payment) }) (err u12)))) ;; Oracle data not found
      
      ;; Validate conditions
      (asserts! (is-eq tx-sender (get recipient payment)) (err u13)) ;; Only recipient can claim
      (asserts! (not (get fulfilled payment)) (err u14)) ;; Payment already fulfilled
      (asserts! (not (get canceled payment)) (err u15)) ;; Payment was canceled
      (asserts! (>= block-height (get unlock-height payment)) (err u16)) ;; Payment still time-locked
      (asserts! (>= (get value oracle-data) (get threshold-value payment)) (err u17)) ;; Threshold condition not met
      
      ;; Mark payment as fulfilled with validated payment-id
      (map-set payments
        { payment-id: payment-id }
        (merge payment { fulfilled: true })
      )
      
      ;; Transfer STX to recipient
      (try! (as-contract (stx-transfer? (get amount payment) tx-sender (get recipient payment))))
      
      (ok true)
    )
  )
)

;; Cancel a payment (sender only, before fulfillment)
(define-public (cancel-payment (payment-id uint))
  (let
    ((payment-info (map-get? payments { payment-id: payment-id })))
    
    ;; Validate payment exists
    (asserts! (is-some payment-info) (err u18)) ;; Payment not found
    
    (let
      ((payment (unwrap-panic payment-info)))
      
      ;; Validate conditions
      (asserts! (is-eq tx-sender (get sender payment)) (err u19)) ;; Only sender can cancel
      (asserts! (not (get fulfilled payment)) (err u20)) ;; Payment already fulfilled
      (asserts! (not (get canceled payment)) (err u21)) ;; Payment already canceled
      
      ;; Mark payment as canceled with validated payment-id
      (map-set payments
        { payment-id: payment-id }
        (merge payment { canceled: true })
      )
      
      ;; Return STX to sender
      (try! (as-contract (stx-transfer? (get amount payment) tx-sender (get sender payment))))
      
      (ok true)
    )
  )
)

;; Check payment status
(define-read-only (get-payment-status (payment-id uint))
  (let ((payment (map-get? payments { payment-id: payment-id })))
    (if (is-none payment)
        (err u22) ;; Payment not found
        (ok (unwrap-panic payment))
    )
  )
)

;; Check if payment is claimable
(define-read-only (is-payment-claimable (payment-id uint))
  (let
    ((payment-info (map-get? payments { payment-id: payment-id })))
    
    (if (is-none payment-info)
        (err u23) ;; Payment not found
        (let
          ((payment (unwrap-panic payment-info))
           (oracle-data (map-get? oracle-values { key: (get oracle-check payment) })))
          
          (if (and
                (not (get fulfilled payment))
                (not (get canceled payment))
                (>= block-height (get unlock-height payment))
                (is-some oracle-data)
                (>= (get value (unwrap-panic oracle-data)) (get threshold-value payment))
              )
              (ok true)
              (ok false)
          )
        )
    )
  )
)

;; Get oracle value
(define-read-only (get-oracle-value (key (string-ascii 128)))
  (map-get? oracle-values { key: key })
)

;; Check if a principal is an authorized oracle
(define-read-only (check-oracle-authorization (provider principal))
  (default-to false (get authorized (map-get? authorized-oracles { provider: provider })))
)

;; Get current payment ID nonce
(define-read-only (get-payment-nonce)
  (var-get payment-id-nonce)
)