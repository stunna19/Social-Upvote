;; Social Engagement Platform Smart Contract

;; This contract implements a decentralized content upvoting system with reputation tracking,
;; content moderation features, and premium boosting capabilities.

;; Constants and Error Codes

;; Error codes
(define-constant ERR-UNAUTHORIZED-ACCESS (err u1000))
(define-constant ERR-ALREADY-UPVOTED (err u1001))
(define-constant ERR-CONTENT-UNAVAILABLE (err u1002))
(define-constant ERR-SELF-UPVOTE-PROHIBITED (err u1003))
(define-constant ERR-UPVOTE-REVERSAL-PROHIBITED (err u1004))
(define-constant ERR-INVALID-PARAMETER-VALUE (err u1005))
(define-constant ERR-PAYMENT-FAILED (err u1006))
(define-constant ERR-CATEGORY-TOO-LONG (err u1007))
(define-constant ERR-HIGHLIGHT-REASON-TOO-LONG (err u1008))
(define-constant ERR-INVALID-CONTENT-ID (err u1009))
(define-constant ERR-EMPTY-STRING (err u1010))

;; Data Maps

;; Content storage with creator and metrics information
(define-map content-registry
  { content-identifier: uint }
  {
    content-creator: principal,
    creation-timestamp: uint,
    upvote-count: uint,
    content-category: (string-ascii 20),
    content-status-active: bool
  }
)

;; Track user interactions with content
(define-map upvote-registry
  { user-address: principal, content-identifier: uint }
  { interaction-timestamp: uint }
)

;; User reputation and activity metrics
(define-map user-reputation-registry
  { user-address: principal }
  {
    reputation-score: uint,
    created-content-count: uint,
    given-upvotes-count: uint,
    account-creation-block: uint
  }
)

;; Highlighted or promoted content registry
(define-map highlighted-content-registry
  { content-identifier: uint }
  {
    highlight-timestamp: uint,
    highlight-reason: (string-ascii 50)
  }
)

;; Data Variables

(define-data-var platform-administrator principal tx-sender)
(define-data-var content-sequence-counter uint u0)
(define-data-var platform-commission-percentage uint u5) ;; 5% commission on premium transactions
(define-data-var reputation-threshold-for-highlighting uint u10) ;; Minimum reputation to highlight content

;; Helper Functions

;; Validate content identifier exists and is active
(define-private (validate-content-exists-and-active (content-id uint))
  (let ((content-details (map-get? content-registry { content-identifier: content-id })))
    (if (is-some content-details)
      (let ((unwrapped-content (unwrap-panic content-details)))
        (if (get content-status-active unwrapped-content)
          (ok unwrapped-content)
          ERR-CONTENT-UNAVAILABLE
        )
      )
      ERR-CONTENT-UNAVAILABLE
    )
  )
)

;; Read-only Functions

;; Retrieve content details by ID
(define-read-only (get-content-details (content-identifier uint))
  (map-get? content-registry { content-identifier: content-identifier })
)

;; Check if user has upvoted specific content
(define-read-only (has-user-upvoted (user-address principal) (content-identifier uint))
  (is-some (map-get? upvote-registry { user-address: user-address, content-identifier: content-identifier }))
)

;; Get user reputation and activity data
(define-read-only (get-user-reputation-data (user-address principal))
  (default-to
    { 
      reputation-score: u0,
      created-content-count: u0,
      given-upvotes-count: u0,
      account-creation-block: (unwrap-panic (get-block-info? time u0))
    }
    (map-get? user-reputation-registry { user-address: user-address })
  )
)

;; Get total number of content items
(define-read-only (get-total-content-count)
  (var-get content-sequence-counter)
)

;; Check if content is highlighted
(define-read-only (is-content-highlighted (content-identifier uint))
  (is-some (map-get? highlighted-content-registry { content-identifier: content-identifier }))
)

;; Get platform commission percentage
(define-read-only (get-platform-commission-rate)
  (var-get platform-commission-percentage)
)

;; Get trending content by category (stub - requires off-chain indexing)
(define-read-only (get-trending-content-by-category (content-category (string-ascii 20)) (result-limit uint))
  ;; This is a simplified implementation - actual implementation would require off-chain indexing
  (err "Please use off-chain indexing service for content ranking queries")
)

;; Content Management Functions

;; Create new content entry
(define-public (publish-content (content-category-input (string-ascii 20)))
  (begin
    ;; Direct validation of input
    (asserts! (> (len content-category-input) u0) ERR-EMPTY-STRING)
    
    (let 
      (
        (content-identifier (var-get content-sequence-counter))
        (creator-address tx-sender)
        (current-block-height (unwrap-panic (get-block-info? time u0)))
        (user-reputation-data (get-user-reputation-data creator-address))
      )
      ;; Increment the content counter
      (var-set content-sequence-counter (+ content-identifier u1))
      
      ;; Register the new content
      (map-set content-registry
        { content-identifier: content-identifier }
        {
          content-creator: creator-address,
          creation-timestamp: current-block-height,
          upvote-count: u0,
          content-category: content-category-input,
          content-status-active: true
        }
      )
      
      ;; Update user profile with new content count
      (map-set user-reputation-registry
        { user-address: creator-address }
        {
          reputation-score: (get reputation-score user-reputation-data),
          created-content-count: (+ (get created-content-count user-reputation-data) u1),
          given-upvotes-count: (get given-upvotes-count user-reputation-data),
          account-creation-block: (get account-creation-block user-reputation-data)
        }
      )
      
      ;; Return the new content identifier
      (ok content-identifier)
    )
  )
)

;; Upvote specific content
(define-public (upvote-content (content-identifier-input uint))
  (begin
    ;; Direct validation of input
    (asserts! (and (>= content-identifier-input u0) 
                  (< content-identifier-input (var-get content-sequence-counter))) 
              ERR-INVALID-CONTENT-ID)
    
    ;; Validate content exists and is active
    (let ((content-details-result (validate-content-exists-and-active content-identifier-input)))
      (match content-details-result
        content-details
        (let
          (
            (user-address tx-sender)
            (content-creator (get content-creator content-details))
            (current-block-height (unwrap-panic (get-block-info? time u0)))
            (voter-reputation-data (get-user-reputation-data user-address))
            (creator-reputation-data (get-user-reputation-data content-creator))
          )
          
          ;; Prevent users from upvoting their own content
          (asserts! (not (is-eq user-address content-creator)) ERR-SELF-UPVOTE-PROHIBITED)
          
          ;; Prevent duplicate upvotes
          (asserts! (not (has-user-upvoted user-address content-identifier-input)) ERR-ALREADY-UPVOTED)
          
          ;; Record the upvote action
          (map-set upvote-registry
            { user-address: user-address, content-identifier: content-identifier-input }
            { interaction-timestamp: current-block-height }
          )
          
          ;; Update content upvote counter
          (map-set content-registry
            { content-identifier: content-identifier-input }
            (merge content-details { upvote-count: (+ (get upvote-count content-details) u1) })
          )
          
          ;; Increase content creator's reputation
          (map-set user-reputation-registry
            { user-address: content-creator }
            {
              reputation-score: (+ (get reputation-score creator-reputation-data) u1),
              created-content-count: (get created-content-count creator-reputation-data),
              given-upvotes-count: (get given-upvotes-count creator-reputation-data),
              account-creation-block: (get account-creation-block creator-reputation-data)
            }
          )
          
          ;; Update voter's upvote count
          (map-set user-reputation-registry
            { user-address: user-address }
            {
              reputation-score: (get reputation-score voter-reputation-data),
              created-content-count: (get created-content-count voter-reputation-data),
              given-upvotes-count: (+ (get given-upvotes-count voter-reputation-data) u1),
              account-creation-block: (get account-creation-block voter-reputation-data)
            }
          )
          
          (ok true)
        )
        error-value (err error-value)
      )
    )
  )
)

;; Remove an upvote (if allowed by time constraints)
(define-public (remove-upvote (content-identifier-input uint))
  (begin
    ;; Direct validation of input
    (asserts! (and (>= content-identifier-input u0) 
                  (< content-identifier-input (var-get content-sequence-counter))) 
              ERR-INVALID-CONTENT-ID)
    
    ;; Validate content exists and is active
    (let ((content-details-result (validate-content-exists-and-active content-identifier-input)))
      (match content-details-result
        content-details
        (let
          (
            (user-address tx-sender)
            (content-creator (get content-creator content-details))
            (upvote-details (unwrap! (map-get? upvote-registry { user-address: user-address, content-identifier: content-identifier-input }) ERR-CONTENT-UNAVAILABLE))
            (current-block-height (unwrap-panic (get-block-info? time u0)))
            (voter-reputation-data (get-user-reputation-data user-address))
            (creator-reputation-data (get-user-reputation-data content-creator))
          )
          
          ;; Verify upvote is recent enough to be reversed (within 10 blocks)
          (asserts! (< (- current-block-height (get interaction-timestamp upvote-details)) u10) ERR-UPVOTE-REVERSAL-PROHIBITED)
          
          ;; Remove the upvote record
          (map-delete upvote-registry { user-address: user-address, content-identifier: content-identifier-input })
          
          ;; Decrease content upvote counter
          (map-set content-registry
            { content-identifier: content-identifier-input }
            (merge content-details { upvote-count: (- (get upvote-count content-details) u1) })
          )
          
          ;; Decrease content creator's reputation
          (map-set user-reputation-registry
            { user-address: content-creator }
            {
              reputation-score: (- (get reputation-score creator-reputation-data) u1),
              created-content-count: (get created-content-count creator-reputation-data),
              given-upvotes-count: (get given-upvotes-count creator-reputation-data),
              account-creation-block: (get account-creation-block creator-reputation-data)
            }
          )
          
          ;; Update voter's upvote count
          (map-set user-reputation-registry
            { user-address: user-address }
            {
              reputation-score: (get reputation-score voter-reputation-data),
              created-content-count: (get created-content-count voter-reputation-data),
              given-upvotes-count: (- (get given-upvotes-count voter-reputation-data) u1),
              account-creation-block: (get account-creation-block voter-reputation-data)
            }
          )
          
          (ok true)
        )
        error-value (err error-value)
      )
    )
  )
)

;; Content Highlighting Functions

;; Highlight content (for admins or high-reputation users)
(define-public (highlight-content (content-identifier-input uint) (highlight-reason-input (string-ascii 50)))
  (begin
    ;; Direct validation of inputs
    (asserts! (and (>= content-identifier-input u0) 
                  (< content-identifier-input (var-get content-sequence-counter))) 
              ERR-INVALID-CONTENT-ID)
    (asserts! (> (len highlight-reason-input) u0) ERR-EMPTY-STRING)
    
    ;; Validate content exists and is active
    (let ((content-details-result (validate-content-exists-and-active content-identifier-input)))
      (match content-details-result
        content-details
        (let
          (
            (user-address tx-sender)
            (is-admin (is-eq user-address (var-get platform-administrator)))
            (user-reputation-data (get-user-reputation-data user-address))
            (user-reputation-value (get reputation-score user-reputation-data))
          )
          
          ;; Verify user has permission to highlight content
          (asserts! (or is-admin (>= user-reputation-value (var-get reputation-threshold-for-highlighting))) ERR-UNAUTHORIZED-ACCESS)
          
          ;; Add content to highlighted registry
          (map-set highlighted-content-registry
            { content-identifier: content-identifier-input }
            {
              highlight-timestamp: (unwrap-panic (get-block-info? time u0)),
              highlight-reason: highlight-reason-input
            }
          )
          
          (ok true)
        )
        error-value (err error-value)
      )
    )
  )
)

;; Remove content from highlighted registry (admin only)
(define-public (remove-content-highlight (content-identifier-input uint))
  (begin
    ;; Direct validation of input
    (asserts! (and (>= content-identifier-input u0) 
                  (< content-identifier-input (var-get content-sequence-counter))) 
              ERR-INVALID-CONTENT-ID)
    
    ;; Verify caller is platform administrator
    (asserts! (is-eq tx-sender (var-get platform-administrator)) ERR-UNAUTHORIZED-ACCESS)
    
    ;; Validate content exists
    (asserts! (is-some (get-content-details content-identifier-input)) ERR-CONTENT-UNAVAILABLE)
    
    ;; Remove from highlighted registry
    (map-delete highlighted-content-registry { content-identifier: content-identifier-input })
    
    (ok true)
  )
)

;; Content Status Management Functions

;; Deactivate content (can be executed by content creator or admin)
(define-public (deactivate-content (content-identifier-input uint))
  (begin
    ;; Direct validation of input
    (asserts! (and (>= content-identifier-input u0) 
                  (< content-identifier-input (var-get content-sequence-counter))) 
              ERR-INVALID-CONTENT-ID)
    
    (let
      (
        (user-address tx-sender)
        (content-details (unwrap! (get-content-details content-identifier-input) ERR-CONTENT-UNAVAILABLE))
        (is-owner (is-eq user-address (get content-creator content-details)))
        (is-admin (is-eq user-address (var-get platform-administrator)))
      )
      
      ;; Verify user has permission to deactivate content
      (asserts! (or is-owner is-admin) ERR-UNAUTHORIZED-ACCESS)
      
      ;; Update content status to inactive
      (map-set content-registry
        { content-identifier: content-identifier-input }
        (merge content-details { content-status-active: false })
      )
      
      ;; Remove from highlighted registry if present
      (if (is-content-highlighted content-identifier-input)
        (map-delete highlighted-content-registry { content-identifier: content-identifier-input })
        true
      )
      
      (ok true)
    )
  )
)

;; Reactivate previously deactivated content (content creator only)
(define-public (reactivate-content (content-identifier-input uint))
  (begin
    ;; Direct validation of input
    (asserts! (and (>= content-identifier-input u0) 
                  (< content-identifier-input (var-get content-sequence-counter))) 
              ERR-INVALID-CONTENT-ID)
    
    (let
      (
        (user-address tx-sender)
        (content-details (unwrap! (get-content-details content-identifier-input) ERR-CONTENT-UNAVAILABLE))
      )
      
      ;; Verify user is content creator
      (asserts! (is-eq user-address (get content-creator content-details)) ERR-UNAUTHORIZED-ACCESS)
      
      ;; Update content status to active
      (map-set content-registry
        { content-identifier: content-identifier-input }
        (merge content-details { content-status-active: true })
      )
      
      (ok true)
    )
  )
)

;; Administrative Functions

;; Update platform commission rate (admin only)
(define-public (update-platform-commission (new-commission-percentage uint))
  (begin
    ;; Verify caller is platform administrator
    (asserts! (is-eq tx-sender (var-get platform-administrator)) ERR-UNAUTHORIZED-ACCESS)
    
    ;; Verify commission is reasonable (0-20%)
    (asserts! (<= new-commission-percentage u20) ERR-INVALID-PARAMETER-VALUE)
    
    ;; Update commission rate
    (var-set platform-commission-percentage new-commission-percentage)
    
    (ok true)
  )
)

;; Update reputation threshold for content highlighting (admin only)
(define-public (update-reputation-threshold (new-reputation-threshold uint))
  (begin
    ;; Verify caller is platform administrator
    (asserts! (is-eq tx-sender (var-get platform-administrator)) ERR-UNAUTHORIZED-ACCESS)
    
    ;; Validate the new threshold is reasonable (avoid setting too high)
    (asserts! (<= new-reputation-threshold u1000) ERR-INVALID-PARAMETER-VALUE)
    
    ;; Update reputation threshold
    (var-set reputation-threshold-for-highlighting new-reputation-threshold)
    
    (ok true)
  )
)

;; Transfer platform administration rights (admin only)
(define-public (transfer-admin-rights (new-administrator principal))
  (begin
    ;; Verify caller is platform administrator
    (asserts! (is-eq tx-sender (var-get platform-administrator)) ERR-UNAUTHORIZED-ACCESS)
    
    ;; Verify new administrator is not null
    (asserts! (not (is-eq new-administrator 'SP000000000000000000002Q6VF78)) ERR-INVALID-PARAMETER-VALUE)
    
    ;; Update administrator
    (var-set platform-administrator new-administrator)
    
    (ok true)
  )
)

;; Premium Features

;; Boost content visibility with STX payment
(define-public (boost-content-visibility (content-identifier-input uint) (boost-payment-amount-input uint))
  (begin
    ;; Direct validation of inputs
    (asserts! (and (>= content-identifier-input u0) 
                  (< content-identifier-input (var-get content-sequence-counter))) 
              ERR-INVALID-CONTENT-ID)
    (asserts! (>= boost-payment-amount-input u100000) ERR-INVALID-PARAMETER-VALUE)
    
    ;; Validate content exists and is active
    (let ((content-details-result (validate-content-exists-and-active content-identifier-input)))
      (match content-details-result
        content-details
        (let
          (
            (user-address tx-sender)
            (platform-fee (/ (* boost-payment-amount-input (var-get platform-commission-percentage)) u100))
            (creator-payment (- boost-payment-amount-input platform-fee))
            (content-creator (get content-creator content-details))
          )
          
          ;; Transfer STX to content creator (minus platform commission)
          (unwrap! (stx-transfer? creator-payment user-address content-creator) ERR-PAYMENT-FAILED)
          
          ;; Transfer commission to platform administrator
          (unwrap! (stx-transfer? platform-fee user-address (var-get platform-administrator)) ERR-PAYMENT-FAILED)
          
          ;; Automatically highlight the boosted content
          (map-set highlighted-content-registry
            { content-identifier: content-identifier-input }
            {
              highlight-timestamp: (unwrap-panic (get-block-info? time u0)),
              highlight-reason: "Premium boosted content"
            }
          )
          
          (ok true)
        )
        error-value (err error-value)
      )
    )
  )
)

;; Contract Initialization

;; Initialize contract with optional new administrator
(define-public (initialize-platform (initial-administrator principal))
  (begin
    ;; Verify caller is current administrator
    (asserts! (is-eq tx-sender (var-get platform-administrator)) ERR-UNAUTHORIZED-ACCESS)
    
    ;; Verify new administrator is not null
    (asserts! (not (is-eq initial-administrator 'SP000000000000000000002Q6VF78)) ERR-INVALID-PARAMETER-VALUE)
    
    ;; Set initial administrator if different from deployer
    (if (not (is-eq (var-get platform-administrator) initial-administrator))
      (var-set platform-administrator initial-administrator)
      true
    )
    
    (ok true)
  )
)