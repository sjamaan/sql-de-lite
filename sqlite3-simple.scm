;; missing: (type-name native-type scheme-value)

#>  #include <sqlite3.h> <#

(module sqlite3-simple
  (

   ;; FFI, for testing
   sqlite3_open sqlite3_close sqlite3_exec
                sqlite3_errcode sqlite3_extended_errcode
                sqlite3_prepare_v2

   ;; API
   error-code error-message
   open-database close-database
   prepare fetch
   raise-errors
   raise-database-error

   ;; debugging
   int->status status->int             
                
                )

  (import scheme chicken)
  (import (only extras fprintf))
  (import (only lolevel pointer->address))
  (import foreign foreigners easyffi)

#>? #include "sqlite3-api.h" <#
  
  (define-foreign-enum-type (sqlite3:type int)
    (type->int int->type)
    ((integer type/integer) SQLITE_INTEGER)
    ((float   type/float)   SQLITE_FLOAT)
    ((text    type/text)    SQLITE_TEXT)
    ((blob    type/blob)    SQLITE_BLOB)
    ((null    type/null)    SQLITE_NULL))

  (define-foreign-enum-type (sqlite3:status int)
    (status->int int->status)
    ((ok status/ok)               SQLITE_OK)
    ((error status/error)         SQLITE_ERROR)
    ((internal status/internal)   SQLITE_INTERNAL)
    ((permission
      status/permission)          SQLITE_PERM)
    ((abort status/abort)         SQLITE_ABORT)
    ((busy status/busy)           SQLITE_BUSY)
    ((locked status/locked)       SQLITE_LOCKED)
    ((no-memory status/no-memory) SQLITE_NOMEM)
    ((read-only status/read-only) SQLITE_READONLY)
    ((interrupt status/interrupt) SQLITE_INTERRUPT)
    ((io-error status/io-error)   SQLITE_IOERR)
    ((corrupt status/corrupt)     SQLITE_CORRUPT)
    ((not-found status/not-found) SQLITE_NOTFOUND)
    ((full status/full)           SQLITE_FULL)
    ((cant-open status/cant-open) SQLITE_CANTOPEN)
    ((protocol status/protocol)   SQLITE_PROTOCOL)
    ((empty status/empty)         SQLITE_EMPTY)
    ((schema status/schema)       SQLITE_SCHEMA)
    ((too-big status/too-big)     SQLITE_TOOBIG)
    ((constraint
      status/constraint)          SQLITE_CONSTRAINT)
    ((mismatch status/mismatch)   SQLITE_MISMATCH)
    ((misuse status/misuse)       SQLITE_MISUSE)
    ((no-lfs status/no-lfs)       SQLITE_NOLFS)
    ((authorization
      status/authorization)       SQLITE_AUTH)
    ((format status/format)       SQLITE_FORMAT)
    ((range status/range)         SQLITE_RANGE)
    ((not-a-database
      status/not-a-database)      SQLITE_NOTADB)
    ((row status/row)             SQLITE_ROW)
    ((done status/done)           SQLITE_DONE))

  (define raise-errors (make-parameter #f))
  
  (define (exec-sql db sql . params)
    (if (null? params)
        (int->status (sqlite3_exec (sqlite-database-ptr db) sql #f #f #f))
        (begin
          (error)
          
         
         )
        
        )
    )

  ;; name doesn't seem right.  also, may now be same as execute!.  but
  ;; execute! can't actually step the statement.  check DBD::SQLite:
  ;; execute steps entire statement when column count is zero,
  ;; returning number of changes.  If columns != 0, it does a step! to
  ;; prepare for fetch (but returns 0 whether data is available or
  ;; not); fetch calls step! after execution.  note that this will run
  ;; an extra step when you don't need it; although you probably normally
  ;; want to step through all results.

  ;; we could have fetch call step! itself prior to fetching; this means
  ;; execute! has nothing to do except for resetting the statement and
  ;; binding any parameters.
  ;; it would mean execute! is equivalent to sqlite3:bind-parameters!.
  ;; 
  (define (exec-statement stmt . params)
    (void)

    )

  ;; returns #f on failure, '() on done, '(col1 col2 ...) on success
  ;; note: "SQL statement" is uncompiled text;
  ;; "prepared statement" is prepared compiled statement.
  ;; sqlite3 egg uses "sql" and "stmt" for these, respectively
  (define (fetch stmt)
    (and-let* ((rv (step! stmt)))
      (case rv
        ((done) '())
        ((row)
         

         )
        (else
         (error 'fetch "internal error: step! result invalid" rv)))
      ))

;;   (let ((st (prepare db "select k, v from cache where k = ?;")))
;;     (do ((i 0 (+ i 1)))
;;         ((> i 100))
;;       (execute! st i)
;;       (match (fetch st)
;;              ((k v) (print (list k v)))
;;              (() (error "no such key" k))))
;;     (finalize! st))

  (define-record sqlite-statement ptr sql)
  (define-record-printer (sqlite-statement s p)
    (fprintf p "#<sqlite-statement ~S>"
             (sqlite-statement-sql s)))
  (define-record sqlite-database ptr filename)
  (define-record-printer (sqlite-database db port)
    (fprintf port "#<sqlite-database 0x~x on ~S>"
             (pointer->address (sqlite-database-ptr db))
             (sqlite-database-filename db)))

  ;; May return #f even on SQLITE_OK, which means the statement contained
  ;; only whitespace and comments and nothing was compiled.
  (define (prepare db sql)
    (let-location ((stmt (c-pointer "sqlite3_stmt")))
      (let ((rv (sqlite3_prepare_v2 (sqlite-database-ptr db)
                                    sql
                                    (string-length sql)
                                    (location stmt)
                                    #f)))
        (cond ((= rv status/ok)
               (if stmt
                   (make-sqlite-statement stmt sql) ; perhaps call library to get SQL
                   #f)) ; not an error, even when raising errors
            ; ((= rv status/busy (retry))) 
              (else ; error?
               (database-error db 'prepare sql))))))

  ;; with prepare_v2: If the database schema changes, instead of
  ;; returning SQLITE_SCHEMA as it always used to do, sqlite3_step()
  ;; will automatically recompile the SQL statement and try to run it again.
  ;; return #f on error, 'row on SQLITE_ROW, 'done on SQLITE_DONE
  ;; alt name.. step-statement! ?
  (define (step! st)
    (void))

  (define (finalize! stmt)
    (void))

  ;; If errors are off, user can't retrieve error message as we
  ;; return #f instead of db; though it's probably SQLITE_CANTOPEN.
  (define (open-database filename)
    (let-location ((db-ptr (c-pointer "sqlite3")))
      (let* ((rv (sqlite3_open filename (location db-ptr)))
             (db (make-sqlite-database db-ptr filename)))
        (if (eqv? rv status/ok)
            db
            (if db-ptr
                (database-error db 'open-database filename)
                (error 'open-database "internal error: out of memory"))))))

  ;; database-error-code?
  (define (error-code db)
    (int->status (sqlite3_errcode (sqlite-database-ptr db))))
  (define (error-message db)
    (sqlite3_errmsg (sqlite-database-ptr db)))

  (define (database-error db where . args)
    (and (raise-errors)
         (apply raise-database-error db where args)))
  (define (raise-database-error db where . args)
    (apply error where (error-message db) args))

;; Optional: prior to close, automatically finalize all open statements using
;;   sqlite3_stmt *pStmt;
;; while( (pStmt = sqlite3_next_stmt(db, 0))!=0 ){
;;     sqlite3_finalize(pStmt);
;; }
  ;; const char *sqlite3_sql(sqlite3_stmt *pStmt);  obtain stmt SQL
  ;;    req. sqlite3_prepare_v2() 


  (define (close-database db)
    (sqlite3_close (sqlite-database-ptr db)) ;; may only return 'ok or 'busy
    ;; what if close twice?
    )

  (define (call-with-prepared-statement db sql proc)
    (void)
    )
  (define (call-with-prepared-statements db sqls proc)  ; sqls is list
    (void)
    )

  ;; (I think (void) and '() should both be treated as NULL)
  ;; careful of return value conflict with '() meaning SQLITE_DONE though
;;   (define void?
;;     (let ((v (void)))
;;       (lambda (x) (eq? v x))))

  


  )
