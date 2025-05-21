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
(define-public (publish-content (content-category (string-ascii 20)))
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
        content-category: content-category,
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

;; Upvote specific content
(define-public (upvote-content (content-identifier uint))
  (let
    (
      (user-address tx-sender)
      (content-details (unwrap! (map-get? content-registry { content-identifier: content-identifier }) ERR-CONTENT-UNAVAILABLE))
      (content-creator (get content-creator content-details))
      (current-block-height (unwrap-panic (get-block-info? time u0)))
      (voter-reputation-data (get-user-reputation-data user-address))
      (creator-reputation-data (get-user-reputation-data content-creator))
    )
    
    ;; Verify content is active
    (asserts! (get content-status-active content-details) ERR-CONTENT-UNAVAILABLE)
    
    ;; Prevent users from upvoting their own content
    (asserts! (not (is-eq user-address content-creator)) ERR-SELF-UPVOTE-PROHIBITED)
    
    ;; Prevent duplicate upvotes
    (asserts! (not (has-user-upvoted user-address content-identifier)) ERR-ALREADY-UPVOTED)
    
    ;; Record the upvote action
    (map-set upvote-registry
      { user-address: user-address, content-identifier: content-identifier }
      { interaction-timestamp: current-block-height }
    )
    
    ;; Update content upvote counter
    (map-set content-registry
      { content-identifier: content-identifier }
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
)

;; Remove an upvote (if allowed by time constraints)
(define-public (remove-upvote (content-identifier uint))
  (let
    (
      (user-address tx-sender)
      (content-details (unwrap! (map-get? content-registry { content-identifier: content-identifier }) ERR-CONTENT-UNAVAILABLE))
      (content-creator (get content-creator content-details))
      (upvote-details (unwrap! (map-get? upvote-registry { user-address: user-address, content-identifier: content-identifier }) ERR-CONTENT-UNAVAILABLE))
      (current-block-height (unwrap-panic (get-block-info? time u0)))
      (voter-reputation-data (get-user-reputation-data user-address))
      (creator-reputation-data (get-user-reputation-data content-creator))
    )
    
    ;; Verify content is active
    (asserts! (get content-status-active content-details) ERR-CONTENT-UNAVAILABLE)
    
    ;; Verify upvote is recent enough to be reversed (within 10 blocks)
    (asserts! (< (- current-block-height (get interaction-timestamp upvote-details)) u10) ERR-UPVOTE-REVERSAL-PROHIBITED)
    
    ;; Remove the upvote record
    (map-delete upvote-registry { user-address: user-address, content-identifier: content-identifier })
    
    ;; Decrease content upvote counter
    (map-set content-registry
      { content-identifier: content-identifier }
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
)

;; Content Highlighting Functions

;; Highlight content (for admins or high-reputation users)
(define-public (highlight-content (content-identifier uint) (highlight-reason (string-ascii 50)))
  (let
    (
      (user-address tx-sender)
      (is-admin (is-eq user-address (var-get platform-administrator)))
      (user-reputation-data (get-user-reputation-data user-address))
      (user-reputation-value (get reputation-score user-reputation-data))
      (content-details (unwrap! (map-get? content-registry { content-identifier: content-identifier }) ERR-CONTENT-UNAVAILABLE))
      (current-block-height (unwrap-panic (get-block-info? time u0)))
    )
    
    ;; Verify user has permission to highlight content
    (asserts! (or is-admin (>= user-reputation-value (var-get reputation-threshold-for-highlighting))) ERR-UNAUTHORIZED-ACCESS)
    
    ;; Verify content is active
    (asserts! (get content-status-active content-details) ERR-CONTENT-UNAVAILABLE)
    
    ;; Add content to highlighted registry
    (map-set highlighted-content-registry
      { content-identifier: content-identifier }
      {
        highlight-timestamp: current-block-height,
        highlight-reason: highlight-reason
      }
    )
    
    (ok true)
  )
)

;; Remove content from highlighted registry (admin only)
(define-public (remove-content-highlight (content-identifier uint))
  (begin
    ;; Verify caller is platform administrator
    (asserts! (is-eq tx-sender (var-get platform-administrator)) ERR-UNAUTHORIZED-ACCESS)
    
    ;; Remove from highlighted registry
    (map-delete highlighted-content-registry { content-identifier: content-identifier })
    
    (ok true)
  )
)

;; Content Status Management Functions

;; Deactivate content (can be executed by content creator or admin)
(define-public (deactivate-content (content-identifier uint))
  (let
    (
      (user-address tx-sender)
      (content-details (unwrap! (map-get? content-registry { content-identifier: content-identifier }) ERR-CONTENT-UNAVAILABLE))
      (is-owner (is-eq user-address (get content-creator content-details)))
      (is-admin (is-eq user-address (var-get platform-administrator)))
    )
    
    ;; Verify user has permission to deactivate content
    (asserts! (or is-owner is-admin) ERR-UNAUTHORIZED-ACCESS)
    
    ;; Update content status to inactive
    (map-set content-registry
      { content-identifier: content-identifier }
      (merge content-details { content-status-active: false })
    )
    
    ;; Remove from highlighted registry if present
    (if (is-content-highlighted content-identifier)
      (map-delete highlighted-content-registry { content-identifier: content-identifier })
      true
    )
    
    (ok true)
  )
)

;; Reactivate previously deactivated content (content creator only)
(define-public (reactivate-content (content-identifier uint))
  (let
    (
      (user-address tx-sender)
      (content-details (unwrap! (map-get? content-registry { content-identifier: content-identifier }) ERR-CONTENT-UNAVAILABLE))
    )
    
    ;; Verify user is content creator
    (asserts! (is-eq user-address (get content-creator content-details)) ERR-UNAUTHORIZED-ACCESS)
    
    ;; Update content status to active
    (map-set content-registry
      { content-identifier: content-identifier }
      (merge content-details { content-status-active: true })
    )
    
    (ok true)
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
    
    ;; Update administrator
    (var-set platform-administrator new-administrator)
    
    (ok true)
  )
)

;; Premium Features

;; Boost content visibility with STX payment
(define-public (boost-content-visibility (content-identifier uint) (boost-payment-amount uint))
  (let
    (
      (user-address tx-sender)
      (content-details (unwrap! (map-get? content-registry { content-identifier: content-identifier }) ERR-CONTENT-UNAVAILABLE))
      (platform-fee (/ (* boost-payment-amount (var-get platform-commission-percentage)) u100))
      (creator-payment (- boost-payment-amount platform-fee))
      (content-creator (get content-creator content-details))
    )
    
    ;; Verify content is active
    (asserts! (get content-status-active content-details) ERR-CONTENT-UNAVAILABLE)
    
    ;; Verify minimum boost amount (0.1 STX = 100000 microSTX)
    (asserts! (>= boost-payment-amount u100000) ERR-INVALID-PARAMETER-VALUE)
    
    ;; Transfer STX to content creator (minus platform commission)
    (unwrap! (stx-transfer? creator-payment user-address content-creator) ERR-PAYMENT-FAILED)
    
    ;; Transfer commission to platform administrator
    (unwrap! (stx-transfer? platform-fee user-address (var-get platform-administrator)) ERR-PAYMENT-FAILED)
    
    ;; Automatically highlight the boosted content
    (map-set highlighted-content-registry
      { content-identifier: content-identifier }
      {
        highlight-timestamp: (unwrap-panic (get-block-info? time u0)),
        highlight-reason: "Premium boosted content"
      }
    )
    
    (ok true)
  )
)

;; Contract Initialization

;; Initialize contract with optional new administrator
(define-public (initialize-platform (initial-administrator principal))
  (begin
    ;; Verify caller is current administrator
    (asserts! (is-eq tx-sender (var-get platform-administrator)) ERR-UNAUTHORIZED-ACCESS)
    
    ;; Set initial administrator if different from deployer
    (if (not (is-eq (var-get platform-administrator) initial-administrator))
      (var-set platform-administrator initial-administrator)
      true
    )
    
    (ok true)
  )
)