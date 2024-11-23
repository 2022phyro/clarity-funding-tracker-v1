;; Public Funding Tracker Contract
;; Tracks allocation and spending of public funds with full transparency

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-project (err u101))
(define-constant err-insufficient-funds (err u102))

;; Data Variables
(define-map projects 
    { project-id: uint }
    {
        name: (string-ascii 50),
        description: (string-ascii 500),
        allocated-amount: uint,
        spent-amount: uint,
        status: (string-ascii 20)
    }
)

(define-map expenditures
    { expenditure-id: uint }
    {
        project-id: uint, 
        amount: uint,
        recipient: principal,
        description: (string-ascii 200),
        date: uint
    }
)

(define-data-var next-project-id uint u1)
(define-data-var next-expenditure-id uint u1)
(define-data-var total-funds-allocated uint u0)
(define-data-var total-funds-spent uint u0)

;; Public Functions

;; Add new project
(define-public (add-project (name (string-ascii 50)) (description (string-ascii 500)) (allocated-amount uint))
    (if (is-eq tx-sender contract-owner)
        (let
            ((project-id (var-get next-project-id)))
            (map-insert projects 
                { project-id: project-id }
                {
                    name: name,
                    description: description,
                    allocated-amount: allocated-amount,
                    spent-amount: u0,
                    status: "ACTIVE"
                }
            )
            (var-set next-project-id (+ project-id u1))
            (var-set total-funds-allocated (+ (var-get total-funds-allocated) allocated-amount))
            (ok project-id)
        )
        err-owner-only
    )
)

;; Record expenditure
(define-public (record-expenditure 
    (project-id uint)
    (amount uint)
    (recipient principal)
    (description (string-ascii 200))
    (date uint))
    (if (is-eq tx-sender contract-owner)
        (let
            ((project (unwrap! (map-get? projects {project-id: project-id}) err-invalid-project))
             (current-spent (get spent-amount project))
             (allocated (get allocated-amount project))
             (expenditure-id (var-get next-expenditure-id)))
            (if (<= (+ current-spent amount) allocated)
                (begin
                    (map-insert expenditures
                        {expenditure-id: expenditure-id}
                        {
                            project-id: project-id,
                            amount: amount,
                            recipient: recipient,
                            description: description,
                            date: date
                        }
                    )
                    (map-set projects
                        {project-id: project-id}
                        (merge project {spent-amount: (+ current-spent amount)})
                    )
                    (var-set next-expenditure-id (+ expenditure-id u1))
                    (var-set total-funds-spent (+ (var-get total-funds-spent) amount))
                    (ok expenditure-id)
                )
                err-insufficient-funds
            )
        )
        err-owner-only
    )
)

;; Read-only functions

(define-read-only (get-project (project-id uint))
    (ok (map-get? projects {project-id: project-id}))
)

(define-read-only (get-expenditure (expenditure-id uint))
    (ok (map-get? expenditures {expenditure-id: expenditure-id}))
)

(define-read-only (get-total-allocated)
    (ok (var-get total-funds-allocated))
)

(define-read-only (get-total-spent)
    (ok (var-get total-funds-spent))
)
