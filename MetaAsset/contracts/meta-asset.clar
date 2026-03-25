;; MetaAsset - Registry of Verified Virtual World & Metaverse Asset Contracts
;; Deployed on the Stacks (STX) blockchain
;; Written in Clarity

;; ============================================================
;; CONSTANTS
;; ============================================================

(define-constant CONTRACT-OWNER tx-sender)

(define-constant ERR-NOT-OWNER          (err u100))
(define-constant ERR-ALREADY-REGISTERED (err u101))
(define-constant ERR-NOT-FOUND          (err u102))
(define-constant ERR-NOT-VERIFIED       (err u103))
(define-constant ERR-UNAUTHORIZED       (err u104))
(define-constant ERR-INVALID-INPUT      (err u105))
(define-constant ERR-ALREADY-VERIFIER   (err u106))
(define-constant ERR-NOT-VERIFIER       (err u107))

;; ============================================================
;; DATA MAPS & VARS
;; ============================================================

;; Total number of registered assets
(define-data-var total-assets uint u0)

;; Asset entry: keyed by contract principal
(define-map assets
  principal
  {
    name:        (string-ascii 64),
    world:       (string-ascii 64),   ;; e.g. "Decentraland", "The Sandbox"
    asset-type:  (string-ascii 32),   ;; e.g. "land", "wearable", "item"
    owner:       principal,
    verified:    bool,
    active:      bool,
    registered-at: uint               ;; block height
  }
)

;; Approved verifiers (addresses that can verify assets)
(define-map verifiers principal bool)

;; Asset ownership index: owner -> list of up to 20 asset principals
(define-map owner-assets
  principal
  (list 20 principal)
)

;; ============================================================
;; PRIVATE HELPERS
;; ============================================================

(define-private (is-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (is-verifier)
  (default-to false (map-get? verifiers tx-sender))
)

(define-private (asset-exists (asset-contract principal))
  (is-some (map-get? assets asset-contract))
)

;; Append a new asset-contract to an owner's tracked list
(define-private (add-to-owner-index (owner principal) (asset-contract principal))
  (let ((current (default-to (list) (map-get? owner-assets owner))))
    (match (as-max-len? (append current asset-contract) u20)
      updated (map-set owner-assets owner updated)
      false   ;; silently cap at 20; caller handles UX
    )
  )
)

;; ============================================================
;; VERIFIER MANAGEMENT  (owner only)
;; ============================================================

(define-public (add-verifier (verifier principal))
  (begin
    (asserts! (is-owner) ERR-NOT-OWNER)
    (asserts! (not (default-to false (map-get? verifiers verifier))) ERR-ALREADY-VERIFIER)
    (map-set verifiers verifier true)
    (ok true)
  )
)

(define-public (remove-verifier (verifier principal))
  (begin
    (asserts! (is-owner) ERR-NOT-OWNER)
    (asserts! (default-to false (map-get? verifiers verifier)) ERR-NOT-VERIFIER)
    (map-delete verifiers verifier)
    (ok true)
  )
)

;; ============================================================
;; ASSET REGISTRATION
;; ============================================================

;; Anyone can register an asset contract they own
(define-public (register-asset
    (asset-contract principal)
    (name          (string-ascii 64))
    (world         (string-ascii 64))
    (asset-type    (string-ascii 32)))
  (begin
    (asserts! (not (asset-exists asset-contract)) ERR-ALREADY-REGISTERED)
    (asserts! (> (len name) u0)       ERR-INVALID-INPUT)
    (asserts! (> (len world) u0)      ERR-INVALID-INPUT)
    (asserts! (> (len asset-type) u0) ERR-INVALID-INPUT)
    (map-set assets asset-contract
      {
        name:           name,
        world:          world,
        asset-type:     asset-type,
        owner:          tx-sender,
        verified:       false,
        active:         true,
        registered-at:  stacks-block-height
      }
    )
    (add-to-owner-index tx-sender asset-contract)
    (var-set total-assets (+ (var-get total-assets) u1))
    (ok true)
  )
)

;; ============================================================
;; ASSET VERIFICATION  (verifier or owner only)
;; ============================================================

(define-public (verify-asset (asset-contract principal))
  (let ((entry (unwrap! (map-get? assets asset-contract) ERR-NOT-FOUND)))
    (asserts! (or (is-verifier) (is-owner)) ERR-UNAUTHORIZED)
    (map-set assets asset-contract (merge entry { verified: true }))
    (ok true)
  )
)

(define-public (revoke-verification (asset-contract principal))
  (let ((entry (unwrap! (map-get? assets asset-contract) ERR-NOT-FOUND)))
    (asserts! (or (is-verifier) (is-owner)) ERR-UNAUTHORIZED)
    (map-set assets asset-contract (merge entry { verified: false }))
    (ok true)
  )
)

;; ============================================================
;; ASSET MANAGEMENT  (asset owner only)
;; ============================================================

;; Deactivate an asset (soft-delete)
(define-public (deactivate-asset (asset-contract principal))
  (let ((entry (unwrap! (map-get? assets asset-contract) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get owner entry)) ERR-UNAUTHORIZED)
    (map-set assets asset-contract (merge entry { active: false }))
    (ok true)
  )
)

;; Reactivate a previously deactivated asset
(define-public (reactivate-asset (asset-contract principal))
  (let ((entry (unwrap! (map-get? assets asset-contract) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get owner entry)) ERR-UNAUTHORIZED)
    (map-set assets asset-contract (merge entry { active: true }))
    (ok true)
  )
)

;; Transfer ownership of a registered asset entry
(define-public (transfer-asset-ownership
    (asset-contract principal)
    (new-owner      principal))
  (let ((entry (unwrap! (map-get? assets asset-contract) ERR-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get owner entry)) ERR-UNAUTHORIZED)
    (map-set assets asset-contract (merge entry { owner: new-owner }))
    (add-to-owner-index new-owner asset-contract)
    (ok true)
  )
)

;; ============================================================
;; READ-ONLY QUERIES
;; ============================================================

;; Get full asset record
(define-read-only (get-asset (asset-contract principal))
  (map-get? assets asset-contract)
)

;; Check if an asset is verified and active
(define-read-only (is-verified-asset (asset-contract principal))
  (match (map-get? assets asset-contract)
    entry (and (get verified entry) (get active entry))
    false
  )
)

;; Get total registered assets
(define-read-only (get-total-assets)
  (var-get total-assets)
)

;; Get assets registered by a specific owner
(define-read-only (get-assets-by-owner (owner principal))
  (default-to (list) (map-get? owner-assets owner))
)

;; Check if an address is an approved verifier
(define-read-only (is-approved-verifier (addr principal))
  (default-to false (map-get? verifiers addr))
)

;; Get the contract owner
(define-read-only (get-contract-owner)
  CONTRACT-OWNER
)