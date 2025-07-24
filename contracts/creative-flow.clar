;; Creative Flow State Induction Contract
;; Triggers and maintains optimal states for artistic and innovative expression

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-INPUT (err u101))
(define-constant ERR-SESSION-NOT-FOUND (err u102))
(define-constant ERR-SESSION-EXPIRED (err u103))
(define-constant MIN-SESSION-DURATION u10)
(define-constant MAX-SESSION-DURATION u480)
(define-constant FLOW-REWARD-RATE u10)

;; Data Variables
(define-data-var session-counter uint u0)
(define-data-var total-flow-time uint u0)

;; Data Maps
(define-map flow-sessions
  { session-id: uint }
  {
    creator: principal,
    start-time: uint,
    duration: uint,
    category: (string-ascii 50),
    flow-score: uint,
    completed: bool,
    rewards-claimed: bool
  }
)

(define-map user-stats
  { user: principal }
  {
    total-sessions: uint,
    total-flow-time: uint,
    average-flow-score: uint,
    best-category: (string-ascii 50),
    level: uint
  }
)

(define-map flow-triggers
  { user: principal, category: (string-ascii 50) }
  {
    optimal-duration: uint,
    preferred-time: uint,
    success-rate: uint,
    last-updated: uint
  }
)

;; Public Functions

;; Start a new flow session
(define-public (start-flow-session (duration uint) (category (string-ascii 50)))
  (let (
    (session-id (+ (var-get session-counter) u1))
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
  )
    (asserts! (and (>= duration MIN-SESSION-DURATION) (<= duration MAX-SESSION-DURATION)) ERR-INVALID-INPUT)
    (asserts! (> (len category) u0) ERR-INVALID-INPUT)

    (map-set flow-sessions
      { session-id: session-id }
      {
        creator: tx-sender,
        start-time: current-time,
        duration: duration,
        category: category,
        flow-score: u0,
        completed: false,
        rewards-claimed: false
      }
    )

    (var-set session-counter session-id)
    (ok session-id)
  )
)

;; Complete a flow session with score
(define-public (complete-flow-session (session-id uint) (flow-score uint))
  (let (
    (session (unwrap! (map-get? flow-sessions { session-id: session-id }) ERR-SESSION-NOT-FOUND))
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
  )
    (asserts! (is-eq (get creator session) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (not (get completed session)) ERR-INVALID-INPUT)
    (asserts! (<= flow-score u100) ERR-INVALID-INPUT)
    (asserts! (>= current-time (+ (get start-time session) (get duration session))) ERR-SESSION-EXPIRED)

    (map-set flow-sessions
      { session-id: session-id }
      (merge session { flow-score: flow-score, completed: true })
    )

    (update-user-stats tx-sender (get category session) (get duration session) flow-score)
    (var-set total-flow-time (+ (var-get total-flow-time) (get duration session)))

    (ok true)
  )
)

;; Claim rewards for completed session
(define-public (claim-session-rewards (session-id uint))
  (let (
    (session (unwrap! (map-get? flow-sessions { session-id: session-id }) ERR-SESSION-NOT-FOUND))
    (reward-amount (* (get flow-score session) FLOW-REWARD-RATE))
  )
    (asserts! (is-eq (get creator session) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (get completed session) ERR-INVALID-INPUT)
    (asserts! (not (get rewards-claimed session)) ERR-INVALID-INPUT)

    (map-set flow-sessions
      { session-id: session-id }
      (merge session { rewards-claimed: true })
    )

    ;; In a real implementation, this would transfer tokens
    (ok reward-amount)
  )
)

;; Update flow triggers based on session performance
(define-public (update-flow-triggers (category (string-ascii 50)) (optimal-duration uint))
  (let (
    (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    (existing-trigger (map-get? flow-triggers { user: tx-sender, category: category }))
  )
    (asserts! (> (len category) u0) ERR-INVALID-INPUT)
    (asserts! (and (>= optimal-duration MIN-SESSION-DURATION) (<= optimal-duration MAX-SESSION-DURATION)) ERR-INVALID-INPUT)

    (match existing-trigger
      trigger (map-set flow-triggers
        { user: tx-sender, category: category }
        (merge trigger {
          optimal-duration: optimal-duration,
          last-updated: current-time
        })
      )
      (map-set flow-triggers
        { user: tx-sender, category: category }
        {
          optimal-duration: optimal-duration,
          preferred-time: current-time,
          success-rate: u0,
          last-updated: current-time
        }
      )
    )

    (ok true)
  )
)

;; Private Functions

(define-private (update-user-stats (user principal) (category (string-ascii 50)) (duration uint) (score uint))
  (let (
    (existing-stats (map-get? user-stats { user: user }))
  )
    (match existing-stats
      stats (map-set user-stats
        { user: user }
        {
          total-sessions: (+ (get total-sessions stats) u1),
          total-flow-time: (+ (get total-flow-time stats) duration),
          average-flow-score: (/ (+ (* (get average-flow-score stats) (get total-sessions stats)) score) (+ (get total-sessions stats) u1)),
          best-category: (if (> score (get average-flow-score stats)) category (get best-category stats)),
          level: (calculate-user-level (+ (get total-sessions stats) u1) (+ (get total-flow-time stats) duration))
        }
      )
      (map-set user-stats
        { user: user }
        {
          total-sessions: u1,
          total-flow-time: duration,
          average-flow-score: score,
          best-category: category,
          level: u1
        }
      )
    )
  )
)

(define-private (calculate-user-level (sessions uint) (total-time uint))
  (+ u1 (/ (+ sessions (/ total-time u60)) u10))
)

;; Read-only Functions

(define-read-only (get-session (session-id uint))
  (map-get? flow-sessions { session-id: session-id })
)

(define-read-only (get-user-stats (user principal))
  (map-get? user-stats { user: user })
)

(define-read-only (get-flow-triggers (user principal) (category (string-ascii 50)))
  (map-get? flow-triggers { user: user, category: category })
)

(define-read-only (get-total-flow-time)
  (var-get total-flow-time)
)

(define-read-only (get-session-counter)
  (var-get session-counter)
)
