;;;; -*- Mode: LISP; Syntax: Ansi-Common-Lisp; Base: 10; Package: S-SQL-TESTS; -*-
(in-package :s-sql-tests)

(fiveam:def-suite :s-sql-tables
    :description "Table suite for s-sql"
    :in :s-sql)

(in-suite :s-sql-tables)

(test expand-table-column
      "Testing expand-table-column"
      (is (equal (s-sql::expand-table-column 'code '(:type varchar :primary-key 't))
                 '("code" " " "VARCHAR" " NOT NULL" " PRIMARY KEY ")))
      (is (equal (s-sql::expand-table-column 'code '(:type (or char db-null) :primary-key 't))
                 '("code" " " "CHAR" " PRIMARY KEY ")))
      (is (equal (s-sql::expand-table-column 'code '(:type (or (string 5) db-null) :primary-key 't))
                 '("code" " " "CHAR(5)" " PRIMARY KEY ")))
      (is (equal (s-sql::expand-table-column 'code '(:type (or (varchar 64) db-null) :collate "en_US.utf8"))
                 '("code" " " "VARCHAR(64)" " COLLATE \"" "en_US.utf8" "\""))))

;;; CREATE TABLE TESTS
(test create-temp-tables
  "Testing create table with temp, unlogged or normal"
  ;;;; Testing global-temporary etc
;;;; Temporary tables are automatically dropped at the end of a session
;;;;
  ;; Note the syntax is temporary or unlogged qualifiers first, then if-not-exists, then table name
  ;; You can use temp or temporary.

      ;; version with :temp and table name in form
      (is (equal (sql (:create-table (:temp 'distributors-in-hell)
                                          ((did :type (or integer db-null)))))
                 "CREATE TEMP TABLE distributors_in_hell (did INTEGER)"))

      ;; version with if-not-exists
      (is (equal (sql (:create-table (:if-not-exists 'distributors-in-hell)
                                          ((did :type (or integer db-null)))))
                 "CREATE TABLE IF NOT EXISTS distributors_in_hell (did INTEGER)"))

      ;; version with temp, if-not-exists and tablename in form
      (is (equal (sql (:create-table (:temp (:if-not-exists 'distributors-in-hell))
                                          ((did :type (or integer db-null)))))
                 "CREATE TEMP TABLE IF NOT EXISTS distributors_in_hell (did INTEGER)"))
      ;; version with if-not-exists and table name in form
      (is (equal (sql (:create-table (:if-not-exists 'distributors-in-hell)
                                          ((did :type (or integer db-null)))))
                "CREATE TABLE IF NOT EXISTS distributors_in_hell (did INTEGER)"))

      ;;;; unlogged tables do not have their data written to the write-ahead log. As a result they are faster,
      ;;; but not crash safe. Any indexes created on an unlogged table are unlogged as well.

      (is (equal (sql (:create-table (:unlogged 'distributors-in-hell)
                                          ((did :type (or integer db-null)))))
                 "CREATE UNLOGGED TABLE distributors_in_hell (did INTEGER)")))

(test create-table-basic
  "Testing Create Table. Replicating from https://www.postgresql.org/docs/10/static/sql-createtable.html"
  ;; Create table films and table distributors:

  ;; The difference with the first four tests are whether the tablename is quoted, unquoted or a string
  ;; or enclosed in a form by itself.
  (is (equal (sql (:create-table 'distributors-in-hell
                                 ((did :type (or integer db-null)))))
             "CREATE TABLE distributors_in_hell (did INTEGER)"))
  (is (equal (sql (:create-table distributors-in-hell
                                 ((did :type (or integer db-null)))))
             "CREATE TABLE distributors_in_hell (did INTEGER)"))
  (is (equal (sql (:create-table "distributors-in-hell"
                                 ((did :type (or integer db-null)))))
             "CREATE TABLE distributors_in_hell (did INTEGER)"))
  ;; version with just table name in form
  (is (equal (sql (:create-table (distributors-in-hell)
                                 ((did :type (or integer db-null)))))
             "CREATE TABLE distributors_in_hell (did INTEGER)"))

  ;; The difference with the first four tests are whether the tablename is a keyword, quoted, unquoted or a string
  ;; preference should be quoted, but your mileage may vary.
  (is (equal (sql (:create-table :films
                                 ((code :type (string 5) :primary-key t)
                                  (len :type (or interval db-null) :interval :hour-to-minute))))
             "CREATE TABLE films (code CHAR(5) NOT NULL PRIMARY KEY , len INTERVAL HOUR TO MINUTE)"))
  (is (equal (sql (:create-table :films
                                 ((code :type (or (string 5) db-null) :constraint 'firstkey :primary-key t)
                                  (len :type (or interval db-null) :interval :hour-to-minute))))
             "CREATE TABLE films (code CHAR(5) CONSTRAINT firstkey PRIMARY KEY , len INTERVAL HOUR TO MINUTE)"))
  (is (equal (sql (:create-table 'films
                                 ((code :type (or (string 5) db-null) :constraint 'firstkey :primary-key t)
                                  (title :type (varchar 40))
                                  (did :type integer)
                                  (date-prod :type (or date db-null))
                                  (kind :type (or (varchar 10) db-null))
                                  (len :type (or interval db-null) :interval :hour-to-minute))))
             "CREATE TABLE films (code CHAR(5) CONSTRAINT firstkey PRIMARY KEY , title VARCHAR(40) NOT NULL, did INTEGER NOT NULL, date_prod DATE, kind VARCHAR(10), len INTERVAL HOUR TO MINUTE)"))
  (is (equal (sql (:create-table films
                                 ((code :type (or (string 5) db-null) :constraint 'firstkey :primary-key t)
                                  (title :type (varchar 40))
                                  (did :type integer)
                                  (date-prod :type (or date db-null))
                                  (kind :type (or (varchar 10) db-null))
                                  (len :type (or interval db-null) :interval :hour-to-minute))))
             "CREATE TABLE films (code CHAR(5) CONSTRAINT firstkey PRIMARY KEY , title VARCHAR(40) NOT NULL, did INTEGER NOT NULL, date_prod DATE, kind VARCHAR(10), len INTERVAL HOUR TO MINUTE)"))
  (is (equal (sql (:create-table  "films"
                                  ((code :type (or (string 5) db-null) :constraint 'firstkey :primary-key t)
                                   (title :type (varchar 40))
                                   (did :type integer)
                                   (date-prod :type (or date db-null))
                                   (kind :type (or (varchar 10) db-null))
                                   (len :type (or interval db-null) :interval :hour-to-minute))))
             "CREATE TABLE films (code CHAR(5) CONSTRAINT firstkey PRIMARY KEY , title VARCHAR(40) NOT NULL, did INTEGER NOT NULL, date_prod DATE, kind VARCHAR(10), len INTERVAL HOUR TO MINUTE)"))
  (is (equal (sql (:create-table 'distributors
                                 ((did :type (or integer db-null)
                                       :primary-key "generated by default as identity")
                                  (name :type (varchar 40) :check (:<> 'name "")))))
             "CREATE TABLE distributors (did INTEGER PRIMARY KEY generated by default as identity, name VARCHAR(40) NOT NULL CHECK (name <> E''))"))
  (is (equal (sql (:create-table 'distributors
                                 ((did :type (or integer db-null)
                                       :primary-key :identity-by-default)
                                  (name :type (varchar 40) :check (:<> 'name "")))))
             "CREATE TABLE distributors (did INTEGER PRIMARY KEY  GENERATED BY DEFAULT AS IDENTITY , name VARCHAR(40) NOT NULL CHECK (name <> E''))"))
  (is (equal (sql (:create-table 'distributors
                                 ((did :type (or integer db-null)
                                       :identity-by-default t :primary-key t)
                                  (name :type (varchar 40) :check (:<> 'name "")))))
             "CREATE TABLE distributors (did INTEGER GENERATED BY DEFAULT AS IDENTITY  PRIMARY KEY , name VARCHAR(40) NOT NULL CHECK (name <> E''))"))

      ;; Create a table with a 2-dimensional array:
  (is (equal (sql (:create-table 'array-int ((vector :type (or int[][] db-null)))))
             "CREATE TABLE array_int (vector INT[][])"))

      ;; a column level unique setting
  (is (equal (sql (:create-table 'person
                                 ((id :type serial :primary-key t)
                                  (first-name :type (varchar 50))
                                  (last-name :type (varchar 50))
                                  (email :type (varchar 50) :unique t))))
             "CREATE TABLE person (id SERIAL NOT NULL PRIMARY KEY , first_name VARCHAR(50) NOT NULL, last_name VARCHAR(50) NOT NULL, email VARCHAR(50) NOT NULL UNIQUE )"))

      ;;  Define a unique table constraint for the table films. Unique table constraints can be defined on one or more columns of the table:
      (is (equal (sql (:create-table 'films
                                     ((code :type (or (string 5) db-null))
                                      (title :type (or (varchar 40) db-null))
                                      (did :type (or integer db-null))
                                      (date-prod :type (or date db-null))
                                      (kind :type (or (varchar 10) db-null))
                                      (len :type (or interval db-null) :interval :hour-to-minute))
                                     (:constraint production :unique 'date-prod)))
                 "CREATE TABLE films (code CHAR(5), title VARCHAR(40), did INTEGER, date_prod DATE, kind VARCHAR(10), len INTERVAL HOUR TO MINUTE, CONSTRAINT production UNIQUE (date_prod))"))

      ;; Define a check column constraint:
      (is (equal (sql (:create-table 'distributors
                                     ((did :type (or integer db-null) :check (:> 'did 100))
                                      (name :type (or (varchar 40) db-null)))))
                 "CREATE TABLE distributors (did INTEGER CHECK (did > 100), name VARCHAR(40))"))

      ;; Define a check table constraint:
      (is (equal (sql (:create-table 'distributors
                                     ((did :type (or integer db-null))
                                      (name :type (or (varchar 40) db-null)))
                                     (:constraint con1 :check (:and (:> 'did 100) (:<> 'name "")))))
                 "CREATE TABLE distributors (did INTEGER, name VARCHAR(40), CONSTRAINT con1 CHECK ((did > 100) and (name <> E'')))"))
      ;; Define a primary key table constraint for the table films:

      (is (equal (sql (:create-table 'films
                             ((code :type (or (string 5) db-null) :constraint 'firstkey :primary-key 't)
                              (title :type (varchar 40))
                              (did :type integer)
                              (date-prod :type (or date db-null))
                              (kind :type (or (varchar 10) db-null))
                              (len :type (or interval db-null) :interval :hour-to-minute))
                             (:constraint code-title :primary-key code title)))
                 "CREATE TABLE films (code CHAR(5) CONSTRAINT firstkey PRIMARY KEY , title VARCHAR(40) NOT NULL, did INTEGER NOT NULL, date_prod DATE, kind VARCHAR(10), len INTERVAL HOUR TO MINUTE, CONSTRAINT code_title PRIMARY KEY (code, title))"))

      ;; Define a primary key constraint for table distributors using table constraint syntax

      (is (equal (sql (:create-table 'distributors
                                     ((did :type (or integer db-null) :check (:> 'did 100))
                                      (name :type (or (varchar 40) db-null)))
                                     (:primary-key did)))
                 "CREATE TABLE distributors (did INTEGER CHECK (did > 100), name VARCHAR(40), PRIMARY KEY (did))"))

      ;; Define a primary key constraint for table distributors using column constraint syntax

      (is (equal (sql (:create-table 'distributors
                                     ((did :type (or integer db-null) :primary-key t)
                                      (name :type (or (varchar 40) db-null)))))
                 "CREATE TABLE distributors (did INTEGER PRIMARY KEY , name VARCHAR(40))"))

      ;; Assign a literal constant default value for the column name, arrange for the default value of column did to be generated by selecting the next value of a sequence object, and make the default value of modtime be the time at which the row is inserted:
      (is (equal (sql (:create-table 'distributors
                                     ((name :type (or (varchar 40) db-null) :default "Luso Films")
                                      (did :type (or integer db-null) :default (:nextval "distributors-serial"))
                                      (modtime :type (or timestamp db-null) :default (:current-timestamp)))))
                 "CREATE TABLE distributors (name VARCHAR(40) DEFAULT E'Luso Films', did INTEGER DEFAULT nextval(E'distributors_serial'), modtime TIMESTAMP DEFAULT current_timestamp)"))

      ;; Define a table with a timestamp with and without a time zones
      (is (equal (sql (:create-table 'account-role
                          ((user-id :type integer)
                           (role-id :type integer)
                           (grant-date :type (or timestamp-without-time-zone db-null)))))
                 "CREATE TABLE account_role (user_id INTEGER NOT NULL, role_id INTEGER NOT NULL, grant_date TIMESTAMP WITHOUT TIME ZONE)"))

      (is (equal (sql (:create-table 'account-role
                                     ((user-id :type integer)
                                      (role-id :type integer)
                                      (grant-date :type (or timestamp-with-time-zone db-null)))))
                 "CREATE TABLE account_role (user_id INTEGER NOT NULL, role_id INTEGER NOT NULL, grant_date TIMESTAMP WITH TIME ZONE)"))

      (is (equal (sql (:create-table 'account-role
                                     ((user-id :type integer)
                                      (role-id :type integer)
                                      (grant-date :type (or timestamptz db-null)))))
                 "CREATE TABLE account_role (user_id INTEGER NOT NULL, role_id INTEGER NOT NULL, grant_date TIMESTAMPTZ)"))


      (is (equal (sql (:create-table 'account-role
                                     ((user-id :type integer)
                                      (role-id :type integer)
                                      (grant-date :type (or timestamp db-null)))))
                 "CREATE TABLE account_role (user_id INTEGER NOT NULL, role_id INTEGER NOT NULL, grant_date TIMESTAMP)"))


      (is (equal (sql (:create-table 'account-role
                                     ((user-id :type integer)
                                      (role-id :type integer)
                                      (grant-date :type (or time db-null)))))
                 "CREATE TABLE account_role (user_id INTEGER NOT NULL, role_id INTEGER NOT NULL, grant_date TIME)"))

      ;; Define two NOT NULL column constraints on the table distributors, one of which is explicitly given a name:

      (is (equal (sql (:create-table 'distributors
                                     ((did :type integer :constraint 'no-null)
                                      (name :type (varchar 40)))))
                 "CREATE TABLE distributors (did INTEGER NOT NULL CONSTRAINT no_null, name VARCHAR(40) NOT NULL)"))

      ;; Define a unique constraint for the name column:
      (is (equal (sql (:create-table 'distributors
                                     ((did :type (or integer db-null))
                                      (name :type (or (varchar 40) db-null) :unique t))))
                 "CREATE TABLE distributors (did INTEGER, name VARCHAR(40) UNIQUE )"))

      ;; The same, specified as a table constraint:
      (is (equal (sql (:create-table 'distributors
                                     ((did :type (or integer db-null))
                                      (name :type (or (varchar 40) db-null)))
                                     (:unique 'name)))
                 "CREATE TABLE distributors (did INTEGER, name VARCHAR(40), UNIQUE (name))"))

      ;; define a unique constraint for the table using two columns
      (is (equal (sql (:create-table 'distributors
                                     ((did :type (or integer db-null))
                                      (name :type (or (varchar 40) db-null)))
                                     (:unique name did)))
                 "CREATE TABLE distributors (did INTEGER, name VARCHAR(40), UNIQUE (name, did))"))

      ;; Create a composite type and a typed table:
      (is (equal (sql (:create-composite-type 'employee-type (name text) (salary numeric) ))
                 "(CREATE TYPE employee_type AS (name text, salary numeric)"))

      ;; Create the same table, specifying 70% fill factor for both the table and its unique index:

      ;; Create table circles with an exclusion constraint that prevents any two circles from overlapping:
      )

(test create-table-with-constraint-and-foreign-keys
  "Testing creating a table with contraints and foreign keys and actions"

  ;; First with foreign key on the column
  (is (equal (sql (:create-table 'so-items
                           ((item-id :type integer)
                            (so-id :type (or integer db-null) :references ((so-headers id)))
                            (product-id :type (or integer db-null))
                            (qty :type (or integer db-null))
                            (net-price :type (or numeric db-null)))
                           (:primary-key item-id so-id)))
             "CREATE TABLE so_items (item_id INTEGER NOT NULL, so_id INTEGER REFERENCES so_headers(id) MATCH SIMPLE ON DELETE RESTRICT ON UPDATE RESTRICT, product_id INTEGER, qty INTEGER, net_price NUMERIC, PRIMARY KEY (item_id, so_id))"))

  ;; now with non-default actions for on delete and on update
  (is (equal (sql (:create-table 'so-items
                           ((item-id :type integer)
                            (so-id :type (or integer db-null) :references ((so-headers id) :no-action :no-action))
                            (product-id :type (or integer db-null))
                            (qty :type (or integer db-null))
                            (net-price :type (or numeric db-null)))
                           (:primary-key item-id so-id)))
             "CREATE TABLE so_items (item_id INTEGER NOT NULL, so_id INTEGER REFERENCES so_headers(id) MATCH SIMPLE ON DELETE NO ACTION ON UPDATE NO ACTION, product_id INTEGER, qty INTEGER, net_price NUMERIC, PRIMARY KEY (item_id, so_id))"))

  ;;Now referencing a group of columns
  (is (equal (sql (:create-table 'so-items
                           ((item-id :type integer)
                            (so-id :type (or integer db-null) :references ((so-headers id p1 p2) :no-action :no-action))
                            (product-id :type (or integer db-null))
                            (qty :type (or integer db-null))
                            (net-price :type (or numeric db-null)))
                           (:primary-key item-id so-id)))
             "CREATE TABLE so_items (item_id INTEGER NOT NULL, so_id INTEGER REFERENCES so_headers(id, p1, p2) MATCH SIMPLE ON DELETE NO ACTION ON UPDATE NO ACTION, product_id INTEGER, qty INTEGER, net_price NUMERIC, PRIMARY KEY (item_id, so_id))"))

  ;; Now with foreign key named at the table level no actions other than the default actions
  (is (equal (sql (:create-table 'account-role
                    ((user-id :type integer)
                     (role-id :type integer)
                     (grant-date :type (or timestamp-without-time-zone db-null)))
                    (:primary-key user-id role-id)
                    (:constraint account-role-role-id-fkey :foreign-key (role-id) (role role-id))))
             "CREATE TABLE account_role (user_id INTEGER NOT NULL, role_id INTEGER NOT NULL, grant_date TIMESTAMP WITHOUT TIME ZONE, PRIMARY KEY (user_id, role_id), CONSTRAINT account_role_role_id_fkey FOREIGN KEY (role_id) REFERENCES role(role_id) MATCH SIMPLE ON DELETE RESTRICT ON UPDATE RESTRICT)"))

  ;; now at the table level with non-default actions
  (is (equal (sql (:create-table 'account-role
                    ((user-id :type integer)
                     (role-id :type integer)
                     (grant-date :type (or timestamp-without-time-zone db-null)))
                    (:primary-key user-id role-id)
                    (:constraint account-role-role-id-fkey :foreign-key (role-id) (role role-id) :no-action :no-action)))
             "CREATE TABLE account_role (user_id INTEGER NOT NULL, role_id INTEGER NOT NULL, grant_date TIMESTAMP WITHOUT TIME ZONE, PRIMARY KEY (user_id, role_id), CONSTRAINT account_role_role_id_fkey FOREIGN KEY (role_id) REFERENCES role(role_id) MATCH SIMPLE ON DELETE NO ACTION ON UPDATE NO ACTION)"))

  ;; now with multiple foreign keys at the table level
  (is (equal (sql (:create-table 'account-role
         ((user-id :type integer)
          (role-id :type integer)
          (grant-date :type (or timestamp-without-time-zone db-null)))
         (:primary-key user-id role-id)
         (:constraint account-role-role-id-fkey
                      :foreign-key (role-id) (role role-id))
         (:constraint account-role-user-id-fkey
                      :foreign-key (user-id) (users user-id))))
             "CREATE TABLE account_role (user_id INTEGER NOT NULL, role_id INTEGER NOT NULL, grant_date TIMESTAMP WITHOUT TIME ZONE, PRIMARY KEY (user_id, role_id), CONSTRAINT account_role_role_id_fkey FOREIGN KEY (role_id) REFERENCES role(role_id) MATCH SIMPLE ON DELETE RESTRICT ON UPDATE RESTRICT, CONSTRAINT account_role_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(user_id) MATCH SIMPLE ON DELETE RESTRICT ON UPDATE RESTRICT)")))

(test create-table-identity
  "Testing generating identity columns"
  (is (equal (sql (:create-table 'color ((color-id :type int :generated-as-identity-always t) (color-name :type varchar))))
             "CREATE TABLE color (color_id INT NOT NULL GENERATED ALWAYS AS IDENTITY , color_name VARCHAR NOT NULL)"))
  (is (equal (sql (:create-table 'color ((color-id :type int :generated-as-identity-by-default t) (color-name :type varchar))))
             "CREATE TABLE color (color_id INT NOT NULL GENERATED BY DEFAULT AS IDENTITY , color_name VARCHAR NOT NULL)"))
  (is (equal (sql (:create-table color ((color-id :type int :generated-as-identity-always t) (color-name :type varchar))))
             "CREATE TABLE color (color_id INT NOT NULL GENERATED ALWAYS AS IDENTITY , color_name VARCHAR NOT NULL)"))
  (is (equal (sql (:create-table "color" ((color-id :type int :generated-as-identity-by-default t) (color-name :type varchar))))
             "CREATE TABLE color (color_id INT NOT NULL GENERATED BY DEFAULT AS IDENTITY , color_name VARCHAR NOT NULL)"))
  (is (equal (sql (:create-table 'color ((color-id :type int :identity-always t) (color-name :type varchar))))
             "CREATE TABLE color (color_id INT NOT NULL GENERATED ALWAYS AS IDENTITY , color_name VARCHAR NOT NULL)"))
  (is (equal (sql (:create-table 'color ((color-id :type int :identity-by-default t) (color-name :type varchar))))
             "CREATE TABLE color (color_id INT NOT NULL GENERATED BY DEFAULT AS IDENTITY , color_name VARCHAR NOT NULL)"))
  (with-test-connection
    (when (table-exists-p 'color) (execute (:drop-table 'color)))
    (query (:create-table 'color ((color-id :type int :generated-as-identity-always t) (color-name :type varchar))))
    (is (equal (table-exists-p 'color) t))
    (query (:insert-into 'color :set 'color-name "Red"))
    (is (equal (length (query (:select '* :from 'color)))
               1))
    (signals database-error (query (:insert-into 'color :set 'color-id 2 'color-name "Green")))
    (execute (:drop-table 'color))
    (query (:create-table 'color ((color-id :type int :generated-as-identity-by-default t) (color-name :type varchar))))
    (query (:insert-into 'color :set 'color-name "White"))
    (is (equal (length (query (:select '* :from 'color)))
               1))
    (query (:insert-into 'color :set 'color-id 2 'color-name "Green"))
    (is (equal (length (query (:select '* :from 'color)))
               2))
    (execute (:drop-table 'color))))


;;; CREATE EXTENDED TABLE TESTS

(test create-extended-temp-tables
  "Testing create table with temp, unlogged or normal"
  ;;;; Testing global-temporary etc
;;;; Temporary tables are automatically dropped at the end of a session
;;;;
      ;; Note the syntax is temporary or unlogged qualifiers first, then if-not-exists, then table name
      ;; You can use temp or temporary
      ;;version with just table name
      (is (equal (sql (:create-extended-table distributors-in-hell
                          ((did :type (or integer db-null)))))
                 "CREATE TABLE distributors_in_hell (did INTEGER)"))

      ;; version with just table name in form
      (is (equal (sql (:create-extended-table (distributors-in-hell)
                                    ((did :type (or integer db-null)))))
          "CREATE TABLE distributors_in_hell (did INTEGER)"))

      ;; version with :temp and table name in form
      (is (equal (sql (:create-extended-table (:temp distributors-in-hell)
                                          ((did :type (or integer db-null)))))
                 "CREATE TEMP TABLE distributors_in_hell (did INTEGER)"))

      ;; version with temp, if-not-exists and tablename in form
      (is (equal (sql (:create-extended-table (:temp (:if-not-exists distributors-in-hell))
                                          ((did :type (or integer db-null)))))
                 "CREATE TEMP TABLE IF NOT EXISTS distributors_in_hell (did INTEGER)"))
      ;; version with if-not-exists and table name in form
      (is (equal (sql (:create-extended-table (:if-not-exists distributors-in-hell)
                                          ((did :type (or integer db-null)))))
                "CREATE TABLE IF NOT EXISTS distributors_in_hell (did INTEGER)"))

      ;;;; unlogged tables do not have their data written to the write-ahead log. As a result they are faster,
      ;;; but not crash safe. Any indexes created on an unlogged table are unlogged as well.

      (is (equal (sql (:create-extended-table (:unlogged distributors-in-hell)
                                          ((did :type (or integer db-null)))))
                 "CREATE UNLOGGED TABLE distributors_in_hell (did INTEGER)")))

(test create-extended-table-basic
  "Testing Create Table. Replicating from https://www.postgresql.org/docs/10/static/sql-createtable.html"
  ;; Create table films and table distributors:
      (is (equal (sql (:create-extended-table films
                             ((code :type (or (string 5) db-null) :constraint 'firstkey :primary-key 't)
                              (title :type (varchar 40))
                              (did :type integer)
                              (date-prod :type (or date db-null))
                              (kind :type (or (varchar 10) db-null))
                              (len :type (or interval db-null) :interval :hour-to-minute))))
                 "CREATE TABLE films (code CHAR(5) CONSTRAINT firstkey PRIMARY KEY , title VARCHAR(40) NOT NULL, did INTEGER NOT NULL, date_prod DATE, kind VARCHAR(10), len INTERVAL HOUR TO MINUTE)"))
      (is (equal (sql (:create-extended-table distributors
                                           ((did :type (or integer db-null)
                                                 :primary-key "generated by default as identity")
                                            (name :type (varchar 40) :check (:<> 'name "")))))
                 "CREATE TABLE distributors (did INTEGER PRIMARY KEY generated by default as identity, name VARCHAR(40) NOT NULL CHECK (name <> E''))"))

      ;; Create a table with a 2-dimensional array:
      (is (equal (sql (:create-extended-table array-int ((vector :type (or int[][] db-null)))))
                 "CREATE TABLE array_int (vector INT[][])"))

      ;;  Define a unique table constraint for the table films. Unique table constraints can be defined on one or more columns of the table:
      (is (equal (sql (:create-extended-table films
                        ((code :type (or (string 5) db-null))
                          (title :type (or (varchar 40) db-null))
                          (did :type (or integer db-null))
                          (date-prod :type (or date db-null))
                          (kind :type (or (varchar 10) db-null))
                          (len :type (or interval db-null) :interval :hour-to-minute))
                        ((:constraint production :unique 'date-prod))))
                 "CREATE TABLE films (code CHAR(5), title VARCHAR(40), did INTEGER, date_prod DATE, kind VARCHAR(10), len INTERVAL HOUR TO MINUTE, CONSTRAINT production UNIQUE (date_prod))"))

      ;; Define a check column constraint:
      (is (equal (sql (:create-extended-table distributors
                                     ((did :type (or integer db-null) :check (:> 'did 100))
                                      (name :type (or (varchar 40) db-null)))))
                 "CREATE TABLE distributors (did INTEGER CHECK (did > 100), name VARCHAR(40))"))

      ;; Define a check table constraint:
      (is (equal (sql (:create-extended-table distributors
                                     ((did :type (or integer db-null))
                                      (name :type (or (varchar 40) db-null)))
                                     ((:constraint con1 :check (:and (:> 'did 100) (:<> 'name ""))))))
                 "CREATE TABLE distributors (did INTEGER, name VARCHAR(40), CONSTRAINT con1 CHECK ((did > 100) and (name <> E'')))"))
      ;; Define a primary key table named constraint for the table films:

      (is (equal (sql (:create-extended-table films
                                              ((code :type (or (string 5) db-null) :constraint 'firstkey :primary-key 't)
                                               (title :type (varchar 40))
                                               (did :type integer)
                                               (date-prod :type (or date db-null))
                                               (kind :type (or (varchar 10) db-null))
                                               (len :type (or interval db-null) :interval :hour-to-minute))
                                              ((:constraint code-title :primary-key code title))))
                 "CREATE TABLE films (code CHAR(5) CONSTRAINT firstkey PRIMARY KEY , title VARCHAR(40) NOT NULL, did INTEGER NOT NULL, date_prod DATE, kind VARCHAR(10), len INTERVAL HOUR TO MINUTE, CONSTRAINT code_title PRIMARY KEY (code, title) )"))

      (is (equal (sql (:create-extended-table so-items
                                              ((item-id :type integer)
                                               (so-id :type (or integer db-null) :references ((so-headers id)))
                                               (product-id :type (or integer db-null))
                                               (qty :type (or integer db-null))
                                               (net-price :type (or numeric db-null)))
                                              ((:primary-key item-id so-id)
                                               (:foreign-key (so-id) (so-headers id)))))
                 "CREATE TABLE so_items (item_id INTEGER NOT NULL, so_id INTEGER REFERENCES so_headers(id) MATCH SIMPLE ON DELETE RESTRICT ON UPDATE RESTRICT, product_id INTEGER, qty INTEGER, net_price NUMERIC, PRIMARY KEY (item_id, so_id) , FOREIGN KEY (so_id) REFERENCES so_headers(id) MATCH SIMPLE ON DELETE RESTRICT ON UPDATE RESTRICT)"))

      ;; with different actions set on the the foreign key reference in the column
      (is (equal (sql (:create-extended-table so-items
                                              ((item-id :type integer)
                                               (so-id :type (or integer db-null) :references ((so-headers id)
                                                                                              :no-action :cascade))
                                               (product-id :type (or integer db-null))
                                               (qty :type (or integer db-null))
                                               (net-price :type (or numeric db-null)))
                                              ((:primary-key item-id so-id)
                                               (:foreign-key (so-id) (so-headers id)))))

                 "CREATE TABLE so_items (item_id INTEGER NOT NULL, so_id INTEGER REFERENCES so_headers(id) MATCH SIMPLE ON DELETE NO ACTION ON UPDATE CASCADE, product_id INTEGER, qty INTEGER, net_price NUMERIC, PRIMARY KEY (item_id, so_id) , FOREIGN KEY (so_id) REFERENCES so_headers(id) MATCH SIMPLE ON DELETE RESTRICT ON UPDATE RESTRICT)"))

      ;; Define a primary key constraint for table distributors using table constraint syntax

      (is (equal (sql (:create-extended-table distributors
                                              ((did :type (or integer db-null) :check (:> 'did 100))
                                               (name :type (or (varchar 40) db-null)))
                                              ((:primary-key did))))
                 "CREATE TABLE distributors (did INTEGER CHECK (did > 100), name VARCHAR(40), PRIMARY KEY (did) )"))

      ;; Similar but adding a reference in a column and the primary key refers to two columns
      (is (equal (sql (:create-extended-table so-items
                                              ((item-id :type integer)
                                               (so-id :type (or integer db-null) :references ((so-headers id)))
                                               (product-id :type (or integer db-null))
                                               (qty :type (or integer db-null))
                                               (net-price :type (or numeric db-null)))
                                              ((:primary-key item-id so-id))))
                 "CREATE TABLE so_items (item_id INTEGER NOT NULL, so_id INTEGER REFERENCES so_headers(id) MATCH SIMPLE ON DELETE RESTRICT ON UPDATE RESTRICT, product_id INTEGER, qty INTEGER, net_price NUMERIC, PRIMARY KEY (item_id, so_id) )"))

      ;; Define a primary key constraint for table distributors using column constraint syntax

      (is (equal (sql (:create-extended-table distributors
                                              ((did :type (or integer db-null) :primary-key t)
                                               (name :type (or (varchar 40) db-null)))))
                 "CREATE TABLE distributors (did INTEGER PRIMARY KEY , name VARCHAR(40))"))

      (is (equal (sql (:create-extended-table child-table
                                              ((c1 :type (or integer db-null) :primary-key)
                                               (c2 :type (or integer db-null))
                                               (c3 :type (or integer db-null)))
                                              ((:foreign-key (c2 c3) (parent-table p1 p2)))))
                 "CREATE TABLE child_table (c1 INTEGER PRIMARY KEY , c2 INTEGER, c3 INTEGER, FOREIGN KEY (c2, c3) REFERENCES parent_table(p1, p2) MATCH SIMPLE ON DELETE RESTRICT ON UPDATE RESTRICT)"
))

      ;; Assign a literal constant default value for the column name, arrange for the default value of column did to be generated by selecting the next value of a sequence object, and make the default value of modtime be the time at which the row is inserted:
      (is (equal (sql (:create-extended-table distributors
                                              ((name :type (or (varchar 40) db-null) :default "Luso Films")
                                               (did :type (or integer db-null) :default (:nextval "distributors-serial"))
                                               (modtime :type (or timestamp db-null) :default (:current-timestamp)))))
                 "CREATE TABLE distributors (name VARCHAR(40) DEFAULT E'Luso Films', did INTEGER DEFAULT nextval(E'distributors_serial'), modtime TIMESTAMP DEFAULT current_timestamp)"))

      ;; Define a table with a timestamp with and without a time zones
      (is (equal (sql (:create-extended-table account-role
                                              ((user-id :type integer)
                                               (role-id :type integer)
                                               (grant-date :type (or timestamp-without-time-zone db-null)))))
                 "CREATE TABLE account_role (user_id INTEGER NOT NULL, role_id INTEGER NOT NULL, grant_date TIMESTAMP WITHOUT TIME ZONE)"))

      (is (equal (sql (:create-extended-table account-role
                                              ((user-id :type integer)
                                               (role-id :type integer)
                                               (grant-date :type (or timestamp-with-time-zone db-null)))))
                 "CREATE TABLE account_role (user_id INTEGER NOT NULL, role_id INTEGER NOT NULL, grant_date TIMESTAMP WITH TIME ZONE)"))

      (is (equal (sql (:create-extended-table account-role
                                              ((user-id :type integer)
                                               (role-id :type integer)
                                               (grant-date :type (or timestamptz db-null)))))
                 "CREATE TABLE account_role (user_id INTEGER NOT NULL, role_id INTEGER NOT NULL, grant_date TIMESTAMPTZ)"))


      (is (equal (sql (:create-extended-table account-role
                                              ((user-id :type integer)
                                               (role-id :type integer)
                                               (grant-date :type (or timestamp db-null)))))
                 "CREATE TABLE account_role (user_id INTEGER NOT NULL, role_id INTEGER NOT NULL, grant_date TIMESTAMP)"))


      (is (equal (sql (:create-extended-table account-role
                                     ((user-id :type integer)
                                      (role-id :type integer)
                                      (grant-date :type (or time db-null)))))
                 "CREATE TABLE account_role (user_id INTEGER NOT NULL, role_id INTEGER NOT NULL, grant_date TIME)"))

      ;; Define two NOT NULL column constraints on the table distributors, one of which is explicitly given a name:

      (is (equal (sql (:create-extended-table distributors
                                     ((did :type integer :constraint 'no-null)
                                      (name :type (varchar 40)))))
                 "CREATE TABLE distributors (did INTEGER NOT NULL CONSTRAINT no_null, name VARCHAR(40) NOT NULL)"))

      ;; Define a unique constraint for the name column:
      (is (equal (sql (:create-extended-table distributors
                                     ((did :type (or integer db-null))
                                      (name :type (or (varchar 40) db-null) :unique t))))
                 "CREATE TABLE distributors (did INTEGER, name VARCHAR(40) UNIQUE )"))

      ;; The same, specified as a table constraint:
      (is (equal (sql (:create-extended-table distributors
                                     ((did :type (or integer db-null))
                                      (name :type (or (varchar 40) db-null)))
                                     ((:unique 'name))))
                 "CREATE TABLE distributors (did INTEGER, name VARCHAR(40), UNIQUE (name))"))

      ;; define a unique constraint for the table using two columns
      (is (equal (sql (:create-extended-table distributors
                                     ((did :type (or integer db-null))
                                      (name :type (or (varchar 40) db-null)))
                                     ((:unique name did))))
                 "CREATE TABLE distributors (did INTEGER, name VARCHAR(40), UNIQUE (name, did))"))

      ;; Create the same table, specifying 70% fill factor for both the table and its unique index:

      (is (equal (sql (:create-extended-table distributors
                                              ((did :type (or integer db-null))
                                               (name :type (or (varchar 40) db-null)))
                                              ((:unique name did :with (:= 'fillfactor 70)))))
                 "CREATE TABLE distributors (did INTEGER, name VARCHAR(40), UNIQUE (name, did) WITH (fillfactor = 70))"))
      (is (equal (sql (:create-extended-table distributors ((did :type (or integer db-null)) (name :type (or (varchar 40) db-null)))
                                              ((:unique name did :with (:= 'fillfactor 70)))
                                              ((:with (:= 'fillfactor 70)))))

                 "CREATE TABLE distributors (did INTEGER, name VARCHAR(40), UNIQUE (name, did) WITH (fillfactor = 70)) WITH (fillfactor = 70)"))
      ;; Create table circles with an exclusion constraint that prevents any two circles from overlapping:
      ;; EXCLUDE IS NOT IMPLEMENTED



      )

(test create-extended-table-with-constraint-and-foreign-keys
  "Testing creating a table with contraints and foreign keys and actions. Note constraint must come first."

 ;; Foreign Key Constraints

;;; From https://stackoverflow.com/questions/28558920/postgresql-foreign-key-syntax
;;; There are three different ways to define a foreign key when creating a table
;;; (when dealing with a single column PK) and they all lead to the same foreign key constraint:

;; Inline without mentioning the target column:
      ;; create table with foreign key references in column. The value for references needs to be a list of references because we
      ;; only pick up one value per constraint. This is for backwards compatibility. Do not shoot the messager.


      (is (equal (sql (:create-extended-table tests ((subject-id :type serial)
                                                     (subject-name :type (or text db-null))
                                                     (higheststudent-id :type (or integer db-null)
                                                                        :references (students)))))
                 "CREATE TABLE tests (subject_id SERIAL NOT NULL, subject_name TEXT, higheststudent_id INTEGER REFERENCES students MATCH SIMPLE ON DELETE RESTRICT ON UPDATE RESTRICT)"))

;;; Inline with mentioning the target column:
      (is (equal (sql (:create-extended-table tests ((subject-id :type serial)
                                                     (subject-name :type (or text db-null))
                                                     (higheststudent-id :type (or integer db-null)
                                                                        :references ((students  student-id))))))
                 "CREATE TABLE tests (subject_id SERIAL NOT NULL, subject_name TEXT, higheststudent_id INTEGER REFERENCES students(student_id) MATCH SIMPLE ON DELETE RESTRICT ON UPDATE RESTRICT)"))

;; Out of line inside the create table:
      (is (equal (sql (:create-extended-table tests ((subject-id :type serial) (subject-name :type (or text db-null))
                                                     (higheststudent-id :type (or integer db-null)))
                                              ((:constraint fk-tests-students :foreign-key (higheststudent-id) (students student-id)))))
                 "CREATE TABLE tests (subject_id SERIAL NOT NULL, subject_name TEXT, higheststudent_id INTEGER, CONSTRAINT fk_tests_students FOREIGN KEY (higheststudent_id) REFERENCES students(student_id) MATCH SIMPLE ON DELETE RESTRICT ON UPDATE RESTRICT)"))

  ;; first with no actions
  (is (equal (sql (:create-extended-table account-role
                    ((user-id :type integer)
                     (role-id :type integer)
                     (grant-date :type (or timestamp-without-time-zone db-null)))
                    ((:constraint account-role-role-id-fkey :primary-key user-id role-id
                                  :foreign-key (role-id) (role role-id)))))
             "CREATE TABLE account_role (user_id INTEGER NOT NULL, role_id INTEGER NOT NULL, grant_date TIMESTAMP WITHOUT TIME ZONE, CONSTRAINT account_role_role_id_fkey PRIMARY KEY (user_id, role_id) FOREIGN KEY (role_id) REFERENCES role(role_id) MATCH SIMPLE ON DELETE RESTRICT ON UPDATE RESTRICT)"))

  ;; now with actions
  (is (equal (sql (:create-extended-table account-role
                    ((user-id :type integer)
                     (role-id :type integer)
                     (grant-date :type (or timestamp-without-time-zone db-null)))
                    ((:constraint account-role-role-id-fkey :primary-key user-id role-id
                                  :foreign-key (role-id) (role role-id) :no-action :no-action))))
             "CREATE TABLE account_role (user_id INTEGER NOT NULL, role_id INTEGER NOT NULL, grant_date TIMESTAMP WITHOUT TIME ZONE, CONSTRAINT account_role_role_id_fkey PRIMARY KEY (user_id, role_id) FOREIGN KEY (role_id) REFERENCES role(role_id) MATCH SIMPLE ON DELETE NO ACTION ON UPDATE NO ACTION)"))

  ;; Now with multiple foreign key constraints
  ;; Example taken from http://www.postgresqltutorial.com/postgresql-create-table/
  (is (equal (sql (:create-extended-table account-role
                     ((user-id :type integer)
                      (role-id :type integer)
                      (grant-date :type (or timestamp-without-time-zone db-null)))
                     ((:primary-key user-id role-id)
                      (:constraint account-role-role-id-fkey
                                   :foreign-key (role-id) (role role-id) :no-action :no-action)
                      (:constraint account-role-user-id-fkey
                                   :foreign-key (user-id) (account user-id) :no-action :no-action))))
             "CREATE TABLE account_role (user_id INTEGER NOT NULL, role_id INTEGER NOT NULL, grant_date TIMESTAMP WITHOUT TIME ZONE, PRIMARY KEY (user_id, role_id) , CONSTRAINT account_role_role_id_fkey FOREIGN KEY (role_id) REFERENCES role(role_id) MATCH SIMPLE ON DELETE NO ACTION ON UPDATE NO ACTION, CONSTRAINT account_role_user_id_fkey FOREIGN KEY (user_id) REFERENCES account(user_id) MATCH SIMPLE ON DELETE NO ACTION ON UPDATE NO ACTION)"))

  ;; now with deferral


  ;; now with matches
  (is (equal (sql (:create-extended-table account-role
                     ((user-id :type integer)
                      (role-id :type integer)
                      (grant-date :type (or timestamp-without-time-zone db-null)))
                     ((:primary-key user-id role-id)
                      (:constraint account-role-role-id-fkey
                                   :foreign-key (role-id) (role role-id) :no-action :no-action :match-simple)
                      (:constraint account-role-user-id-fkey
                                   :foreign-key (user-id) (account user-id) :no-action :no-action :match-simple))))
           "CREATE TABLE account_role (user_id INTEGER NOT NULL, role_id INTEGER NOT NULL, grant_date TIMESTAMP WITHOUT TIME ZONE, PRIMARY KEY (user_id, role_id) , CONSTRAINT account_role_role_id_fkey FOREIGN KEY (role_id) REFERENCES role(role_id) MATCH SIMPLE ON DELETE NO ACTION ON UPDATE NO ACTION, CONSTRAINT account_role_user_id_fkey FOREIGN KEY (user_id) REFERENCES account(user_id) MATCH SIMPLE ON DELETE NO ACTION ON UPDATE NO ACTION)")))

(test create-table-with-extended-table-parameters
  "Testing the extensions beyond the end of the parens!"
  (is (equal (sql (:create-extended-table cinemas ((id :type serial) (name :type (or text db-null)) (location :type (or text db-null)))
                                          ()
                                          ((:tablespace diskvol1))))
             "CREATE TABLE cinemas (id SERIAL NOT NULL, name TEXT, location TEXT) TABLESPACE diskvol1"))
  ;; Create a range partitioned table:

  (is (equal (sql (:create-extended-table measurement
                                          ((logdate :type date)
                                           (peaktemp :type (or integer db-null))
                                           (unitsales :type (or integer db-null)))
                                          ()
                                          ((:partition-by-range 'logdate))))
"CREATE TABLE measurement (logdate DATE NOT NULL, peaktemp INTEGER, unitsales INTEGER) PARTITION BY RANGE (logdate)"))
;; Create a range partitioned table with multiple columns in the partition key:


  (is (equal (sql (:create-extended-table measurement-year-month
                                          ((logdate :type date)
                                           (peaktemp :type (or integer db-null))
                                           (unitsales :type (or integer db-null)))
                                          ()
                                          ((:partition-by-range (:extract 'year 'logdate)(:extract 'month 'logdate)))))
             "CREATE TABLE measurement_year_month (logdate DATE NOT NULL, peaktemp INTEGER, unitsales INTEGER) PARTITION BY RANGE (EXTRACT(year FROM logdate), EXTRACT(month FROM logdate))")))

(test create-extended-table-identity
  "Testing generating identity columns"
  (is (equal (sql (:create-extended-table color ((color-id :type int :generated-as-identity-always t) (color-name :type varchar))))
             "CREATE TABLE color (color_id INT NOT NULL GENERATED ALWAYS AS IDENTITY , color_name VARCHAR NOT NULL)"))
  (is (equal (sql (:create-extended-table color ((color-id :type int :generated-as-identity-by-default t) (color-name :type varchar))))
             "CREATE TABLE color (color_id INT NOT NULL GENERATED BY DEFAULT AS IDENTITY , color_name VARCHAR NOT NULL)"))
  (with-test-connection
    (when (table-exists-p 'color) (execute (:drop-table 'color)))
    (query (:create-extended-table color ((color-id :type int :generated-as-identity-always t) (color-name :type varchar))))
    (is (equal (table-exists-p 'color) t))
    (is (table-exists-p :color))
    (query (:insert-into 'color :set 'color-name "Red"))
    (is (equal (length (query (:select '* :from 'color)))
               1))
    (signals database-error (query (:insert-into 'color :set 'color-id 2 'color-name "Green")))
    (execute (:drop-table 'color))
    (query (:create-extended-table color ((color-id :type int :generated-as-identity-by-default t) (color-name :type varchar))))
    (query (:insert-into 'color :set 'color-name "White"))
    (is (equal (length (query (:select '* :from 'color)))
               1))
    (query (:insert-into 'color :set 'color-id 2 'color-name "Green"))
    (is (equal (length (query (:select '* :from 'color)))
               2))
    (execute (:drop-table 'color))))

(test create-table-full-1
      "Test :create-table with extended table constraints."
      (is (equal (s-sql:sql
                  (:create-table-full faa.d_airports
			                                ((AirportID :type integer)
			                                 (Name      :type text)
			                                 (City      :type text)
			                                 (Country   :type text)
			                                 (airport_code :type text)
			                                 (ICOA_code :type text)
			                                 (Latitude  :type float8)
			                                 (Longitude :type float8)
			                                 (Altitude  :type float8)
			                                 (TimeZoneOffset :type float)
			                                 (DST_Flag  :type text)
			                                 (TZ        :type text))
			                                ()
			                                ((:distributed-by (airport_code)))))
	               "CREATE TABLE faa.d_airports (airportid INTEGER NOT NULL, name TEXT NOT NULL, city TEXT NOT NULL, country TEXT NOT NULL, airport_code TEXT NOT NULL, icoa_code TEXT NOT NULL, latitude FLOAT8 NOT NULL, longitude FLOAT8 NOT NULL, altitude FLOAT8 NOT NULL, timezoneoffset REAL NOT NULL, dst_flag TEXT NOT NULL, tz TEXT NOT NULL) DISTRIBUTED BY (airport_code) ")))


(test drop-table
  "Testing drop-table method."
  (is (equal (sql (:drop-table 'george))
             "DROP TABLE george"))
  (is (equal (sql (:drop-table :if-exists 'george))
             "DROP TABLE IF EXISTS george"))
  (is (equal (sql (:drop-table :if-exists 'george :cascade))
             "DROP TABLE IF EXISTS george CASCADE"))
  (is (equal (sql (:drop-table  (:if-exists 'george) :cascade))
             "DROP TABLE IF EXISTS george CASCADE")))

(test alter-table
  "Testing the alter-table sql-op"
  (is (equal (sql (:alter-table 'test-uniq :drop-constraint 'test-uniq-pkey))
             "ALTER TABLE test_uniq DROP CONSTRAINT test_uniq_pkey"))
  (is (equal (sql (:alter-table "test-uniq" :drop-constraint "test-uniq-pkey"))
             "ALTER TABLE test_uniq DROP CONSTRAINT test_uniq_pkey"))
  (is (equal (sql (:alter-table "test-uniq" :add-column 'address :type (or (varchar 40) db-null)))
             "ALTER TABLE test_uniq ADD COLUMN address VARCHAR(40)"))
  (is (equal (sql (:alter-table "test-uniq" :drop-column 'address))
             "ALTER TABLE test_uniq DROP COLUMN address"))
  (is (equal (sql (:alter-table "test-uniq" :rename-column 'address 'city))
             "ALTER TABLE test_uniq RENAME COLUMN address TO city"))
  (is (equal (sql (:alter-table 'distributors ((:rename-column 'address 'city))))
             "ALTER TABLE distributors RENAME COLUMN address TO city"))
  (is (equal (sql (:alter-table "test-uniq" :rename 'test-unique))
             "ALTER TABLE test_uniq RENAME TO test_unique"))
  (is (equal (sql (:alter-table 'distributors :add :primary-key 'dist-id))
             "ALTER TABLE distributors ADD PRIMARY KEY (dist_id)"))
  (is (equal (sql (:alter-table "test-uniq" :add-constraint silly-key :primary-key 'code 'title))
             "ALTER TABLE test_uniq ADD CONSTRAINT silly_key PRIMARY KEY (code, title)"))
  (is (equal (sql (:alter-table 'distributors :drop-column 'address :restrict))
            "ALTER TABLE distributors DROP COLUMN address RESTRICT"))
  (is (equal (sql (:alter-table 'distributors ((:alter-column 'address :type (or (varchar 80) db-null))
                                               (:alter-column 'name :type (or (varchar 100) db-null)))))
             "ALTER TABLE distributors ALTER COLUMN address  TYPE VARCHAR(80), ALTER COLUMN name  TYPE VARCHAR(100)")))

(test alter-column
  "Testing altering columns specifically"
  ;; change type
  (is (equal (sql (:alter-table "test2" :alter-column "description" :type varchar))
             "ALTER TABLE test2 ALTER COLUMN description  TYPE VARCHAR NOT NULL"))
  ;; change type nullable
  (is (equal (sql (:alter-table "test2" :alter-column "description" :type (or varchar db-null)))
             "ALTER TABLE test2 ALTER COLUMN description  TYPE VARCHAR"))
  ;; Change type allowing nullable column and limiting length
  (is (equal (sql (:alter-table "test2" :alter-column "description" :type (or (varchar 64) db-null)))
             "ALTER TABLE test2 ALTER COLUMN description  TYPE VARCHAR(64)"))
  ;; change type not-null
  (is (equal (sql (:alter-table "test2" :alter-column "description" :type (varchar 64)))
             "ALTER TABLE test2 ALTER COLUMN description  TYPE VARCHAR(64) NOT NULL"))
  ;; To change the collation of a column
  (is (equal (sql (:alter-table "test2" :alter-column "description" :type (or (varchar 64) db-null)
                                :collate "en_US.utf8"))
             "ALTER TABLE test2 ALTER COLUMN description  TYPE VARCHAR(64) COLLATE \"en_US.utf8\""))
;; change type timestamp with quoted table and column
  (is (equal (sql (:alter-table 'test2 :alter-column 'time :type (or :timestamp-with-time-zone db-null)))
             "ALTER TABLE test2 ALTER COLUMN time  TYPE TIMESTAMP WITH TIME ZONE"))
  ;; To remove a default constraint from a column
  (is (equal (sql (:alter-table 'distributors :alter-column 'street :drop-default))

             "ALTER TABLE distributors ALTER COLUMN street  DROP DEFAULT "))
  ;; To remove a not-null constraint from a column using keyword :not-null
  (is (equal (sql (:alter-table 'distributors :alter-column   'street :drop-not-null))
             "ALTER TABLE distributors ALTER COLUMN street  DROP NOT NULL "))
  ;; to set a column as not null using keyword not-null
  (is (equal (sql (:alter-table 'distributors :alter-column 'street :set-not-null))
             "ALTER TABLE distributors ALTER COLUMN street  SET NOT NULL "))
  ;; set default expression
  (is (equal (sql (:alter-table 'distributors :alter-column 'street :set-default  (:now)))
             "ALTER TABLE distributors ALTER COLUMN street  SET DEFAULT now()"))
  ;; drop identity
  (is (equal (sql (:alter-table 'distributors :alter-column 'street :drop-identity 'george))
             "ALTER TABLE distributors ALTER COLUMN street  DROP IDENTITY george"))
  ;; add identity
  (is (equal (sql (:alter-table 'distributors :alter-column 'street :add-identity-by-default t))
             "ALTER TABLE distributors ALTER COLUMN street  ADD GENERATED BY DEFAULT AS IDENTITY "))
  (is (equal (sql (:alter-table 'distributors :alter-column 'street :add-identity-always t))
             "ALTER TABLE distributors ALTER COLUMN street  ADD GENERATED ALWAYS AS IDENTITY "))
  (is (equal (sql (:alter-table 'distributors :alter-column 'did :add-identity-always "start with 10 increment by 10"))
             "ALTER TABLE distributors ALTER COLUMN did  ADD GENERATED ALWAYS AS IDENTITY (start with 10 increment by 10)"))
  (is (equal (sql (:alter-table 'distributors :alter-column 'street :add-identity-by-default t :set-statistics 1300))
             "ALTER TABLE distributors ALTER COLUMN street  ADD GENERATED BY DEFAULT AS IDENTITY SET STATISTICS 1300 ")))
