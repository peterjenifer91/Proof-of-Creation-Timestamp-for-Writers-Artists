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

(define-data-var verification-fee uint u1000)
(define-data-var validator-count uint u0)

(define-map validators
    { validator: principal }
    { 
        is-active: bool,
        verifications-count: uint,
        reputation-score: uint
    }
)

(define-map verification-requests
    { request-id: uint }
    {
        creation-id: uint,
        requester: principal,
        validator: (optional principal),
        status: (string-ascii 20),
        fee-paid: uint,
        submitted-at: uint
    }
)

(define-map creation-verifications
    { creation-id: uint }
    {
        is-verified: bool,
        verified-by: (optional principal),
        verified-at: (optional uint),
        verification-level: (string-ascii 20)
    }
)

(define-data-var last-verification-request-id uint u0)

(define-public (add-validator (validator principal))
    (begin
        (asserts! (is-eq tx-sender contract-caller) (err u100))
        (map-set validators
            { validator: validator }
            {
                is-active: true,
                verifications-count: u0,
                reputation-score: u100
            }
        )
        (var-set validator-count (+ (var-get validator-count) u1))
        (ok true)
    )
)

(define-public (request-verification (creation-id uint))
    (let
        (
            (new-request-id (+ (var-get last-verification-request-id) u1))
            (fee (var-get verification-fee))
        )
        (asserts! (is-some (get-creation creation-id)) (err u101))
        (asserts! (is-none (map-get? creation-verifications { creation-id: creation-id })) (err u102))
        
        (try! (stx-transfer? fee tx-sender (as-contract tx-sender)))
        
        (map-set verification-requests
            { request-id: new-request-id }
            {
                creation-id: creation-id,
                requester: tx-sender,
                validator: none,
                status: "pending",
                fee-paid: fee,
                submitted-at: burn-block-height
            }
        )
        
        (var-set last-verification-request-id new-request-id)
        (ok new-request-id)
    )
)

(define-public (accept-verification (request-id uint))
    (let
        ((request (unwrap! (map-get? verification-requests { request-id: request-id }) (err u103))))
        (asserts! (is-some (map-get? validators { validator: tx-sender })) (err u104))
        (asserts! (is-eq (get status request) "pending") (err u105))
        
        (map-set verification-requests
            { request-id: request-id }
            (merge request { 
                validator: (some tx-sender),
                status: "in-progress"
            })
        )
        (ok true)
    )
)

(define-public (complete-verification (request-id uint) (verification-result bool))
    (let
        (
            (request (unwrap! (map-get? verification-requests { request-id: request-id }) (err u106)))
            (validator-info (unwrap! (map-get? validators { validator: tx-sender }) (err u107)))
        )
        (asserts! (is-eq (some tx-sender) (get validator request)) (err u108))
        (asserts! (is-eq (get status request) "in-progress") (err u109))
        
        (map-set verification-requests
            { request-id: request-id }
            (merge request { status: "completed" })
        )
        
        (map-set creation-verifications
            { creation-id: (get creation-id request) }
            {
                is-verified: verification-result,
                verified-by: (some tx-sender),
                verified-at: (some burn-block-height),
                verification-level: "standard"
            }
        )
        
        (map-set validators
            { validator: tx-sender }
            (merge validator-info { 
                verifications-count: (+ (get verifications-count validator-info) u1)
            })
        )
        
        (if verification-result
            (try! (as-contract (stx-transfer? (get fee-paid request) tx-sender (get requester request))))
            (try! (as-contract (stx-transfer? (/ (get fee-paid request) u2) tx-sender tx-sender)))
        )
        
        (ok verification-result)
    )
)

(define-read-only (get-verification-status (creation-id uint))
    (map-get? creation-verifications { creation-id: creation-id })
)

(define-read-only (get-verification-request (request-id uint))
    (map-get? verification-requests { request-id: request-id })
)

(define-read-only (is-validator (validator principal))
    (is-some (map-get? validators { validator: validator }))
)

(define-data-var platform-fee-percentage uint u250)

(define-map creation-royalties
    { creation-id: uint }
    {
        royalty-percentage: uint,
        license-price: uint,
        is-for-sale: bool,
        exclusive-license: bool,
        commercial-allowed: bool
    }
)

(define-map licenses
    { license-id: uint }
    {
        creation-id: uint,
        licensee: principal,
        license-type: (string-ascii 20),
        price-paid: uint,
        expires-at: (optional uint),
        granted-at: uint
    }
)

(define-map royalty-earnings
    { creator: principal }
    { total-earned: uint }
)

(define-data-var last-license-id uint u0)

(define-public (set-royalty-terms (creation-id uint) (royalty-percentage uint) (license-price uint) (commercial-allowed bool))
    (let
        ((creation (unwrap! (get-creation creation-id) (err u200))))
        (asserts! (is-eq tx-sender (get owner creation)) (err u201))
        (asserts! (<= royalty-percentage u5000) (err u202))
        
        (map-set creation-royalties
            { creation-id: creation-id }
            {
                royalty-percentage: royalty-percentage,
                license-price: license-price,
                is-for-sale: true,
                exclusive-license: false,
                commercial-allowed: commercial-allowed
            }
        )
        (ok true)
    )
)

(define-public (purchase-license (creation-id uint) (license-type (string-ascii 20)))
    (let
        (
            (creation (unwrap! (get-creation creation-id) (err u203)))
            (royalty-info (unwrap! (map-get? creation-royalties { creation-id: creation-id }) (err u204)))
            (license-price (get license-price royalty-info))
            (creator (get owner creation))
            (new-license-id (+ (var-get last-license-id) u1))
            (platform-fee (/ (* license-price (var-get platform-fee-percentage)) u10000))
            (creator-payment (- license-price platform-fee))
        )
        (asserts! (get is-for-sale royalty-info) (err u205))
        (asserts! (not (is-eq tx-sender creator)) (err u206))
        
        (try! (stx-transfer? license-price tx-sender (as-contract tx-sender)))
        (try! (as-contract (stx-transfer? creator-payment tx-sender creator)))
        
        (map-set licenses
            { license-id: new-license-id }
            {
                creation-id: creation-id,
                licensee: tx-sender,
                license-type: license-type,
                price-paid: license-price,
                expires-at: none,
                granted-at: burn-block-height
            }
        )
        
        (let
            ((current-earnings (default-to { total-earned: u0 } (map-get? royalty-earnings { creator: creator }))))
            (map-set royalty-earnings
                { creator: creator }
                { total-earned: (+ (get total-earned current-earnings) creator-payment) }
            )
        )
        
        (var-set last-license-id new-license-id)
        (ok new-license-id)
    )
)

(define-public (set-exclusive-license (creation-id uint) (licensee principal) (price uint) (duration-blocks uint))
    (let
        (
            (creation (unwrap! (get-creation creation-id) (err u207)))
            (royalty-info (unwrap! (map-get? creation-royalties { creation-id: creation-id }) (err u208)))
            (creator (get owner creation))
            (new-license-id (+ (var-get last-license-id) u1))
            (platform-fee (/ (* price (var-get platform-fee-percentage)) u10000))
            (creator-payment (- price platform-fee))
        )
        (asserts! (is-eq tx-sender creator) (err u209))
        (asserts! (get is-for-sale royalty-info) (err u210))
        
        (try! (stx-transfer? price licensee (as-contract tx-sender)))
        (try! (as-contract (stx-transfer? creator-payment tx-sender creator)))
        
        (map-set licenses
            { license-id: new-license-id }
            {
                creation-id: creation-id,
                licensee: licensee,
                license-type: "exclusive",
                price-paid: price,
                expires-at: (some (+ burn-block-height duration-blocks)),
                granted-at: burn-block-height
            }
        )
        
        (map-set creation-royalties
            { creation-id: creation-id }
            (merge royalty-info { exclusive-license: true })
        )
        
        (var-set last-license-id new-license-id)
        (ok new-license-id)
    )
)

(define-public (withdraw-royalties)
    (let
        ((earnings (unwrap! (map-get? royalty-earnings { creator: tx-sender }) (err u211))))
        (asserts! (> (get total-earned earnings) u0) (err u212))
        
        (try! (as-contract (stx-transfer? (get total-earned earnings) tx-sender tx-sender)))
        
        (map-set royalty-earnings
            { creator: tx-sender }
            { total-earned: u0 }
        )
        (ok (get total-earned earnings))
    )
)

(define-read-only (get-royalty-info (creation-id uint))
    (map-get? creation-royalties { creation-id: creation-id })
)

(define-read-only (get-license (license-id uint))
    (map-get? licenses { license-id: license-id })
)

(define-read-only (get-creator-earnings (creator principal))
    (map-get? royalty-earnings { creator: creator })
)

(define-read-only (check-license-validity (license-id uint))
    (let
        ((license (map-get? licenses { license-id: license-id })))
        (if (is-some license)
            (let
                ((license-data (unwrap-panic license)))
                (if (is-some (get expires-at license-data))
                    (ok (> (unwrap-panic (get expires-at license-data)) burn-block-height))
                    (ok true)
                )
            )
            (err u213)
        )
    )
)