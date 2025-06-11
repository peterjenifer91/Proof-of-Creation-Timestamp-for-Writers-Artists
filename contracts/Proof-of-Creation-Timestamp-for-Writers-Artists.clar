(define-data-var last-creation-id uint u0)

(define-map creations
    { creation-id: uint }
    {
        owner: principal,
        ipfs-hash: (string-ascii 64),
        title: (string-ascii 100),
        timestamp: uint,
        category: (string-ascii 20)
    }
)

(define-map creator-works
    { creator: principal }
    { work-ids: (list 100 uint) }
)

(define-public (register-creation (ipfs-hash (string-ascii 64)) (title (string-ascii 100)) (category (string-ascii 20)))
    (let
        (
            (new-id (+ (var-get last-creation-id) u1))
            (creator tx-sender)
            (existing-works (default-to { work-ids: (list) } (map-get? creator-works { creator: tx-sender })))
        )
        (asserts! (>= (len ipfs-hash) u1) (err u1))
        (asserts! (>= (len title) u1) (err u2))
        (asserts! (>= (len category) u1) (err u3))
        
        (map-set creations
            { creation-id: new-id }
            {
                owner: creator,
                ipfs-hash: ipfs-hash,
                title: title,
                timestamp: burn-block-height,
                category: category
            }
        )
        
        (map-set creator-works
            { creator: creator }
            { work-ids: (unwrap-panic (as-max-len? (append (get work-ids existing-works) new-id) u100)) }
        )
        
        (var-set last-creation-id new-id)
        (ok new-id)
    )
)

(define-read-only (get-creation (creation-id uint))
    (map-get? creations { creation-id: creation-id })
)

(define-read-only (get-creator-works (creator principal))
    (map-get? creator-works { creator: creator })
)

(define-read-only (verify-timestamp (creation-id uint) (claimed-height uint))
    (let
        ((creation (map-get? creations { creation-id: creation-id })))
        (if (is-some creation)
            (ok (is-eq claimed-height (get timestamp (unwrap-panic creation))))
            (err u4)
        )
    )
)

(define-public (transfer-creation (creation-id uint) (new-owner principal))
    (let
        ((creation (map-get? creations { creation-id: creation-id })))
        (asserts! (is-some creation) (err u5))
        (asserts! (is-eq tx-sender (get owner (unwrap-panic creation))) (err u6))
        
        (map-set creations
            { creation-id: creation-id }
            (merge (unwrap-panic creation) { owner: new-owner })
        )
        (ok true)
    )
)

(define-read-only (get-creation-count)
    (var-get last-creation-id)
)
