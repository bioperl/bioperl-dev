;; $Id$
;; test suite (HA!) for bioperl-mode
;; uses test.el package by wang liang (included in test dir)
(require 'bioperl-mode)
(unless (require 'test)
  (push load-path ".")
  (unless (require 'test)
    (error "Unit tests require the package `test.el'")))

(defun bioperl-set-test-path ()
  "Init module cache and set test path for bioperl-mode unit tests."
  (setq bioperl-module-names-cache '(("Bio")))
  (setq bioperl-module-path "./test-path-1;./test-path-2"))

;;
;; finders and filename splitters
;;
;; check bioperl-path-from-perl, bioperl-split-name

(defcase bioperl-filename-handler-tests (:bpmode) 'bioperl-set-test-path
  ;; generate real paths from double-colon format
  (test-assert-string-equal (bioperl-path-from-perl "Bio::SeqIO::fasta") 
			    "./test-path-1/Bio/SeqIO/fasta.pm")
  ;; test directory vs. pm 
  (test-assert-string-equal (bioperl-path-from-perl "Bio::SeqIO")
			    "./test-path-1/Bio/SeqIO.pm")
  (test-assert-string-equal (bioperl-path-from-perl "Bio::SeqIO" t)
			    "./test-path-1/Bio/SeqIO")  
  ;; name splits
  ;; module-first
  (test-assert-equal (bioperl-split-name "Bio::SeqIO" nil) '("Bio" "SeqIO"))
  ;; directory-first
  (test-assert-equal (bioperl-split-name "Bio::SeqIO" t) '("Bio::SeqIO" nil))
  (test-assert-equal (bioperl-split-name "Bio::SeqIO::fasta" t) '("Bio::SeqIO" "fasta"))
  (test-assert-equal (bioperl-split-name "Bio::SeqIO::fasta" 1) '("*Bio::SeqIO::fasta" nil))
  ;; partial names
  (test-assert-equal (bioperl-split-name "Bio::Se" nil) '("Bio" "*Se"))
  (test-assert-equal (bioperl-split-name "Bio::Se" t) '("*Bio::Se" nil))

  )

;;
;; module name cache loading
;;

(defcase bioperl-module-cache-loading-tests (:bpmode) 'bioperl-set-test-path
    ;; slurp module names correctly
    (test-assert-= (length (bioperl-slurp-module-names "Bio::SeqIO")) 24 )
    (test-assert-ok (setq alist (bioperl-slurp-module-names "Bio::SeqIO")))
    (test-assert-ok (listp (assoc "Handler" alist)))
    (test-assert-eq nil (cdr (assoc "Handler" alist)))
    (test-assert-string-equal "0" (cdr (assoc "MultiFile" alist)))
    ;; can't find if not in desired path
    (test-assert-ok (null (bioperl-slurp-module-names "Bio::SeqIO" 1)))
    ;; test-path-2
    (test-assert-ok (setq alist (bioperl-slurp-module-names "Bio::DB" 1)))
    (test-assert-ok (listp (assoc "Biblio" alist)))
    (test-assert-eq nil (cdr (assoc "Biblio" alist)))
    (test-assert-string-equal "1" (cdr (assoc "EMBL" alist)))

    ;; add to cache
    ;; clear first
    (setq bioperl-module-names-cache '(("Bio")))
    (test-assert-ok (bioperl-add-module-names-to-cache "Bio::SeqIO"))
    ;; shouldn't hit cache if already there
    (test-assert-ok (null (bioperl-add-module-names-to-cache "Bio::SeqIO")))
    ;; add from other path
    (test-assert-ok (bioperl-add-module-names-to-cache "Bio::DB" 1))
    ;; test recursive addition
    (test-assert-ok (bioperl-add-module-names-to-cache "Bio::DB::SeqFeature::Store::DBI" 1))
    ;; add a common branch
    (test-assert-ok (bioperl-add-module-names-to-cache "Bio::Nexml" 0))
    ;; should add from the other path
    (test-assert-ok (bioperl-add-module-names-to-cache "Bio::Nexml" 1))    
    ;; should not add again
    (test-assert-ok (null (bioperl-add-module-names-to-cache "Bio::Nexml" 0)))
    (test-assert-ok (null (bioperl-add-module-names-to-cache "Bio::Nexml" 1)))
)
		    
;;
;; cache searches 
;;

(defcase bioperl-cache-search-tests (:bpmode) 'bioperl-set-test-path
  ;; set up cache
  (test-assert-ok (bioperl-add-module-names-to-cache "Bio::SeqIO"))
  (test-assert-ok (bioperl-add-module-names-to-cache "Bio::DB" 1))
  (test-assert-ok (bioperl-add-module-names-to-cache "Bio::Nexml" 0))
  (test-assert-ok (bioperl-add-module-names-to-cache "Bio::Nexml" 1))
  (test-assert-ok (bioperl-add-module-names-to-cache "Bio::DB::SeqFeature::Store::DBI" 1))
  ;; look deep
  (test-assert-string-equal (car (elt 
				       (deep-assoc-all 
					(split-string 
					 "Bio::DB::SeqFeature::Store::DBI::Pg" 
					 "::") bioperl-module-names-cache) 
				       0)) "Pg")
  (test-assert-string-equal (cdr (elt 
				       (deep-assoc-all 
					(split-string 
					 "Bio::DB::SeqFeature::Store::DBI::Pg" 
					 "::") bioperl-module-names-cache) 
				       0)) "1")
  ;; check the common path
  (test-assert-string-equal (cdr (deep-assoc '("Bio" "Nexml" "Factory")
						   bioperl-module-names-cache)) "1;0")
				       
  )

;;
;; method name loading tests
;;

(defcase bioperl-method-cache-loading-tests (bpmode) nil
  )

;;
;; completion
;;
;; check bioperl-namespace-completion-function, 
;;  bioperl-make-collection, bioperl-completing-read

(defcase bioperl-completion-tests (:bpmode) 'bioperl-set-test-path
  (setq test-complete '("Bio"))
  (test-assert-equal (bioperl-namespace-completion-function "" nil t) test-complete )
  (setq test-complete '("Bio::"))
  (test-assert-equal (bioperl-namespace-completion-function "B" nil t) test-complete )
  (test-assert-equal (bioperl-namespace-completion-function "Bi" nil t) test-complete )
  (setq test-complete '("Bio::DB" "Bio::Nexml" "Bio::SeqIO"))
  (test-assert-equal (bioperl-namespace-completion-function "Bio:" nil t) test-complete )
  (test-assert-equal (bioperl-namespace-completion-function "Bio::" nil t) test-complete )
  (setq test-complete '("Bio::SeqIO"))
  (test-assert-equal (bioperl-namespace-completion-function "Bio::S" nil t) test-complete )
  (test-assert-equal (bioperl-namespace-completion-function "Bio::Se" nil t) test-complete )
  (setq test-complete (sort '("Bio::SeqIO" "Bio::SeqIO::Handler" "Bio::SeqIO::game" "Bio::SeqIO::tinyseq") 'string-lessp))
  (test-assert-equal (bioperl-namespace-completion-function "Bio::SeqIO" nil t) test-complete )
  ;; test on cleared cache
  (setq bioperl-module-names-cache '(("Bio")))
 (test-assert-equal (bioperl-namespace-completion-function "Bio::SeqIO" nil t) test-complete )
  ;; trailing colons
 (pop test-complete)
 (test-assert-equal (bioperl-namespace-completion-function "Bio::SeqIO:" nil t) test-complete )
 (test-assert-equal (bioperl-namespace-completion-function "Bio::SeqIO::" nil t) test-complete )
 ;; modules
 (setq bioperl-module-names-cache '(("Bio")))
 (setq test-complete (sort '("Bio" "Bio::SeqIO" "Bio::SeqIO::FTHelper" "Bio::SeqIO::MultiFile" "Bio::SeqIO::abi" "Bio::SeqIO::ace" "Bio::SeqIO::agave" "Bio::SeqIO::alf" "Bio::SeqIO::asciitree" "Bio::SeqIO::bsml" "Bio::SeqIO::bsml_sax" "Bio::SeqIO::chadoxml" "Bio::SeqIO::chaos" "Bio::SeqIO::chaosxml" "Bio::SeqIO::ctf" "Bio::SeqIO::embl" "Bio::SeqIO::embldriver" "Bio::SeqIO::entrezgene" "Bio::SeqIO::excel" "Bio::SeqIO::exp" "Bio::SeqIO::fasta" "Bio::SeqIO::game" "Bio::SeqIO::tinyseq") 'string-lessp))
 (test-assert-equal (sort (mapcar 'car (bioperl-make-collection "Bio::SeqIO" nil)) 'string-lessp ) test-complete)
)

;;
;; pod rendering
;;

(defcase pod-viewer-tests (:bpmode) nil
  )

;;
;; user functions
;;

(defcase bioperl-use-case-tests (:bpmode) nil
  )

;;
;; run 'em and read the buffer *test-result*
;;

(test-run-tags ':bpmode)

