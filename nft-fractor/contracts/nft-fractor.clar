;; NFT Fractor - Split expensive NFTs into smaller shares
;; This contract allows fractionalization of NFTs into fungible tokens

;; Define NFT trait for compatibility
(define-trait nft-trait
  (
    (transfer (uint principal principal) (response bool uint))
    (get-owner (uint) (response (optional principal) uint))
  )
)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-ALREADY-EXISTS (err u409))
(define-constant ERR-INVALID-AMOUNT (err u400))
(define-constant ERR-INSUFFICIENT-BALANCE (err u402))
(define-constant ERR-NOT-OWNER (err u403))
(define-constant ERR-FRACTION-NOT-FOUND (err u405))
(define-constant ERR-INVALID-SHARE-AMOUNT (err u406))
(define-constant ERR-BUYOUT-THRESHOLD-NOT-MET (err u407))

;; Contract owner
(define-constant CONTRACT-OWNER tx-sender)

;; Data structures
(define-map fractionalized-nfts
  { nft-contract: principal, token-id: uint }
  {
    owner: principal,
    total-shares: uint,
    share-price: uint,
    shares-outstanding: uint,
    buyout-threshold: uint,
    created-at: uint
  }
)

(define-map user-shares
  { user: principal, nft-contract: principal, token-id: uint }
  { shares: uint }
)

(define-map share-balances
  { nft-contract: principal, token-id: uint }
  { total-supply: uint }
)

;; Events
(define-data-var next-fraction-id uint u1)

;; Read-only functions
(define-read-only (get-fraction-info (nft-contract principal) (token-id uint))
  (map-get? fractionalized-nfts { nft-contract: nft-contract, token-id: token-id })
)

(define-read-only (get-user-shares (user principal) (nft-contract principal) (token-id uint))
  (default-to 
    { shares: u0 }
    (map-get? user-shares { user: user, nft-contract: nft-contract, token-id: token-id })
  )
)

(define-read-only (get-share-balance (nft-contract principal) (token-id uint))
  (default-to 
    { total-supply: u0 }
    (map-get? share-balances { nft-contract: nft-contract, token-id: token-id })
  )
)

;; Private functions
(define-private (transfer-nft-to-contract (nft-contract <nft-trait>) (token-id uint) (owner principal))
  (contract-call? nft-contract transfer token-id owner (as-contract tx-sender))
)

(define-private (transfer-nft-from-contract (nft-contract <nft-trait>) (token-id uint) (recipient principal))
  (as-contract (contract-call? nft-contract transfer token-id tx-sender recipient))
)

;; Public functions

;; Fractionalize an NFT
(define-public (fractionalize-nft 
  (nft-contract <nft-trait>) 
  (token-id uint) 
  (total-shares uint) 
  (share-price uint)
  (buyout-threshold uint))
  (let (
    (fraction-key { nft-contract: (contract-of nft-contract), token-id: token-id })
    (caller tx-sender)
  )
    ;; Validate inputs
    (asserts! (> total-shares u0) ERR-INVALID-AMOUNT)
    (asserts! (> share-price u0) ERR-INVALID-AMOUNT)
    (asserts! (and (> buyout-threshold u50) (<= buyout-threshold u100)) ERR-INVALID-AMOUNT)
    
    ;; Check if already fractionalized
    (asserts! (is-none (map-get? fractionalized-nfts fraction-key)) ERR-ALREADY-EXISTS)
    
    ;; Transfer NFT to contract (assumes standard NFT trait)
    (try! (transfer-nft-to-contract nft-contract token-id caller))
    
    ;; Create fraction record
    (map-set fractionalized-nfts fraction-key {
      owner: caller,
      total-shares: total-shares,
      share-price: share-price,
      shares-outstanding: total-shares,
      buyout-threshold: buyout-threshold,
      created-at: block-height
    })
    
    ;; Set initial share balance
    (map-set share-balances fraction-key {
      total-supply: total-shares
    })
    
    ;; Give all shares to the original owner initially
    (map-set user-shares 
      { user: caller, nft-contract: (contract-of nft-contract), token-id: token-id }
      { shares: total-shares }
    )
    
    (ok fraction-key)
  )
)

;; Buy shares
(define-public (buy-shares (nft-contract principal) (token-id uint) (shares-to-buy uint))
  (let (
    (fraction-key { nft-contract: nft-contract, token-id: token-id })
    (fraction-info (unwrap! (map-get? fractionalized-nfts fraction-key) ERR-FRACTION-NOT-FOUND))
    (buyer tx-sender)
    (current-shares (get shares (get-user-shares buyer nft-contract token-id)))
    (cost (* shares-to-buy (get share-price fraction-info)))
  )
    ;; Validate purchase
    (asserts! (> shares-to-buy u0) ERR-INVALID-SHARE-AMOUNT)
    (asserts! (<= shares-to-buy (get shares-outstanding fraction-info)) ERR-INSUFFICIENT-BALANCE)
    
    ;; Transfer STX payment to contract
    (try! (stx-transfer? cost buyer (as-contract tx-sender)))
    
    ;; Update user shares
    (map-set user-shares 
      { user: buyer, nft-contract: nft-contract, token-id: token-id }
      { shares: (+ current-shares shares-to-buy) }
    )
    
    ;; Update shares outstanding
    (map-set fractionalized-nfts fraction-key
      (merge fraction-info { 
        shares-outstanding: (- (get shares-outstanding fraction-info) shares-to-buy)
      })
    )
    
    (ok shares-to-buy)
  )
)

;; Sell shares back
(define-public (sell-shares (nft-contract principal) (token-id uint) (shares-to-sell uint))
  (let (
    (fraction-key { nft-contract: nft-contract, token-id: token-id })
    (fraction-info (unwrap! (map-get? fractionalized-nfts fraction-key) ERR-FRACTION-NOT-FOUND))
    (seller tx-sender)
    (current-shares (get shares (get-user-shares seller nft-contract token-id)))
    (payout (* shares-to-sell (get share-price fraction-info)))
  )
    ;; Validate sale
    (asserts! (> shares-to-sell u0) ERR-INVALID-SHARE-AMOUNT)
    (asserts! (<= shares-to-sell current-shares) ERR-INSUFFICIENT-BALANCE)
    
    ;; Update user shares
    (map-set user-shares 
      { user: seller, nft-contract: nft-contract, token-id: token-id }
      { shares: (- current-shares shares-to-sell) }
    )
    
    ;; Update shares outstanding
    (map-set fractionalized-nfts fraction-key
      (merge fraction-info { 
        shares-outstanding: (+ (get shares-outstanding fraction-info) shares-to-sell)
      })
    )
    
    ;; Transfer STX payout to seller
    (try! (as-contract (stx-transfer? payout tx-sender seller)))
    
    (ok shares-to-sell)
  )
)

;; Buyout functionality - if someone owns enough shares, they can buy out the NFT
(define-public (buyout-nft (nft-contract <nft-trait>) (token-id uint))
  (let (
    (fraction-key { nft-contract: (contract-of nft-contract), token-id: token-id })
    (fraction-info (unwrap! (map-get? fractionalized-nfts fraction-key) ERR-FRACTION-NOT-FOUND))
    (buyer tx-sender)
    (buyer-shares (get shares (get-user-shares buyer (contract-of nft-contract) token-id)))
    (total-shares (get total-shares fraction-info))
    (ownership-percentage (/ (* buyer-shares u100) total-shares))
  )
    ;; Check if buyer has enough shares for buyout
    (asserts! (>= ownership-percentage (get buyout-threshold fraction-info)) ERR-BUYOUT-THRESHOLD-NOT-MET)
    
    ;; Transfer NFT to buyer
    (try! (transfer-nft-from-contract nft-contract token-id buyer))
    
    ;; Remove fraction record
    (map-delete fractionalized-nfts fraction-key)
    (map-delete share-balances fraction-key)
    
    ;; Clear buyer's shares
    (map-delete user-shares { user: buyer, nft-contract: (contract-of nft-contract), token-id: token-id })
    
    (ok true)
  )
)

;; Emergency function - only contract owner can use
(define-public (emergency-withdraw (nft-contract <nft-trait>) (token-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (try! (transfer-nft-from-contract nft-contract token-id CONTRACT-OWNER))
    (ok true)
  )
)