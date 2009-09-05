;; $Id$

;; use multiple paths in bioperl-module-path

;;
;; Bioperl minor (haha!) mode
;; 
;; Author: Mark A. Jensen
;; Email : maj -at- fortinbras -dot- us
;;
;; Part of The Documentation Project
;; http://www.bioperl.org/wiki/The_Documentation_Project

;; Copyright (C) 2009 Mark A. Jensen

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3 of
;; the License, or (at your option) any later version.

;; This program is distributed in the hope that it will be
;; useful, but WITHOUT ANY WARRANTY; without even the implied
;; warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
;; PURPOSE.  See the GNU General Public License for more details.

;; You should have received a copy of the GNU General Public
;; License along with this program; if not, write to the Free
;; Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301 USA

;;
;;
;; TODOs
;;
;;  - compile to byte code
;;
;; back-compatibility issue
;; - require a completing-read that works with emacs 21
;;   * no "test-completion" method
;;   * completing-read COLLECTION of 22 is TABLE of 21, 
;;     which must be an alist 
;; issues
;; - bioperl-view-mode isn't always getting its keymap
;; - missing tool in tool-bar??
;; - xemacs support?
;;
;; Installation
;;
;;  The files bioperl-mode.el, bioperl-skel.el, and bioperl-init.el
;;  should be placed in $EMACS_ROOT/site-lisp, and the .xpm image
;;  files in $EMACS_ROOT/etc/images, then add
;;  (require 'bioperl-mode)
;;  to your .emacs file.
;;
;;  See http://www.bioperl.org/wiki/Emacs_bioperl-mode
;;  for more information.
;;
;; Design Notes
;; 
;; POD content is obtained exclusively by accessing the user's installed
;; Bioperl modules -- so it's as up-to-date as the user's installation.
;;
;; POD is parsed first by calling out to pod2text; I believe this is a
;; standard utility with perl distributions.
;;
;; Much of the parsing in this package depends on the standard form of
;; Bioperl pod; particularly on the typical division into NAME,
;; SYNOPSIS, DESCRIPTION, and APPENDIX sections, and on the fact that
;; pod for individual methods is found in the APPENDIX. There is some
;; dependence on the usual head levels for the headers, but this can
;; be hacked out if necessary.
;;
;; Some attempts at efficiency were made. Parsing pod for methods
;; and associated data can take a while, so parse results are cached
;; for the last module so parsed, and the cache is checked when 
;; method information is requested before parsing again.
;;
;; The Bio/ path is parsed to provide a namespace completion facility
;; The relevant path names and structure is stored in an alist tree
;; called bioperl-module-names-cache. The cache is loaded lazily,
;; so that the directory structure is accessed on a desire-to-know 
;; basis.
;;
;; Lazy loading of the name cache necessitated "programmed completion"
;; of namespace names in prompts. See Programmed Completion in the 
;; info (elisp) node, and the function 
;; bioperl-namespace-completion-function.
;;
;; Skeletons (implemented in the emacs standard package skeleton.el)
;; have been used for template insertions. These are very powerful, if
;; cumbersome, offer plug-in interactor functions, and I think allow
;; more modularity and scope for new additions than (insert)ing text
;; 'by hand'. Skeletons and (define-skeleton) declarations are
;; distributed in a separate file 'bioperl-skel.el', which is loaded
;; when the mode is initialized.
;;                                                                        

(require 'skeleton)
(require 'bioperl-skel)
(require 'bioperl-init)

;; (load-file "~/bioperl/docproj/bioperl-mode/bioperl-init.el")
;; (load-file "~/bioperl/docproj/bioperl-mode/bioperl-skel.el")

(defconst bioperl-mode-revision "$Id$"
  "The revision string of bioperl-mode.el")

;;
;; User customizations
;;

(defgroup bioperl nil
  "BioPerl templates and documentation access")

(defcustom bioperl-mode-active-on-perl-mode-flag t
  "If set, perl-mode will begin with bioperl-mode active.
Boolean."
  :type 'boolean
  :group 'bioperl)

(defcustom bioperl-mode-safe-flag t
  "If set, bioperl-mode with substitute `exec-path' with `bioperl-safe-PATH'.
Nil means use your current `exec-path'."
  :type 'boolean
  :group 'bioperl)

(defcustom bioperl-pod2text-args '("")
  "A list of pod2text arguments.
Must be single characters preceded by dashes. Args used with
pod2text when viewing full pod. Do 'pod2text --help' for
possibilities."
  :type 'sexp
  :group 'bioperl
  )

(defcustom bioperl-safe-PATH '()
  "Safe exec-path for bioperl-mode."
  :type 'sexp
  :initialize 'bioperl-set-safe-PATH
  :group 'bioperl)

(defcustom bioperl-system-pod2text nil
  "Contains the path to the pod2text command.
On init, set is attempted by `bioperl-find-system-pod2text'."
  :type 'file
  :initialize 'bioperl-find-system-pod2text
  :group 'bioperl)

(defcustom bioperl-module-path nil
  "Local path to Bioperl modules.
On init, set is attempted by `bioperl-find-module-path' Can indicate multiple search paths; define as PATH in your OS. The environment variable BPMODE_PATH will override everything."
;; better type 'choice; do later
  :type 'string
  :initialize 'bioperl-find-module-path
  :group 'bioperl)

;;
;; Hooks
;;

;;
;; bioperl- namespace variables
;;

(defvar bioperl-method-pod-cache nil
  "Stores the alist returned by the last successful `bioperl-slurp-methods-from-pod' call.
The module filepath represented by the cached info is contained
in `bioperl-cached-module'.")

(defvar bioperl-cached-module nil
  "Contains the filepath whose method pod information is
  currently stored in `bioperl-method-pod-cache'.")

(defvar bioperl-module-names-cache nil
  "Storage for an alist tree structure of available module names.
Structure follows the Bio library tree:
 ( (\"Bio\" \"Seq\" ( \"SeqIO\" \"fasta\" \"msf\" ...) \"PrimarySeqI\" ...  ) )
Use `bioperl-add-module-names-to-cache' to, well, do it.")

;;
;; User-interface functions
;;

(defun bioperl-insert-module (namespace module &optional beg pt end)
  "Insert BioPerl module declaration interactively, using completion."
  (interactive
   (let* (
	 (mod-at-pt (bioperl-module-at-point))
	 (beg (if mod-at-pt (match-beginning 0) nil))
	 (pt (point))
	 (end (if mod-at-pt (match-end 0) nil))
	 (cr (bioperl-completing-read mod-at-pt nil nil "[insert] " t) )
	 )
     (if (not (member nil (mapcar 'not cr))) (signal 'quit t))
     (append cr (list beg pt end))
     ))
  (if namespace
      (progn
	(setq namespace (replace-regexp-in-string "::$" "" namespace))
	(let ( 
	      ( mod (apply 'concat 
			   namespace 
			   (if module (list "::" module) '(nil))) )
	      )
	  (if (not beg)
	      (insert mod)
	    (string-match (concat 
			   (buffer-substring beg pt)
			   "\\(.*\\)")
			  mod)
	    (delete-region pt end)
	    (insert (substring mod (match-beginning 1) (match-end 1))))))
    nil))

;;
;; pod viewers
;;

(defun bioperl-view-pod (module)
  "View the full pod for a BioPerl module."
  (interactive
   (let (
	 (mod (bioperl-completing-read (bioperl-module-at-point) nil t "[pod] "))
	 )
     (if (not (member nil (mapcar 'not mod))) (signal 'quit t))     
     (list (apply 'concat 
		  (elt mod 0) 
		  (if (elt mod 1) (list "::" (elt mod 1)) 
		    (signal 'quit t))))))
  (bioperl-view-full-pod module))

(defun bioperl-view-pod-method (namespace module method)
  "View desired method pod interactively. Use completion facilities to browse."
  (interactive 
   (let (
	 (cr (bioperl-completing-read (bioperl-module-at-point) t nil "[pod mth] ") )
	 )
     (if (not (member nil (mapcar 'not cr))) (signal 'quit t))
     cr))
  (if (not method) (signal 'quit t))
  (let (
	( cache-pos (if method (assoc method bioperl-method-pod-cache) nil) )
	)
    (if (not cache-pos)
	(message "No such method")
      (bioperl-render-method-pod-from-cons cache-pos))
    ))

(defun bioperl-view-pod-synopsis (module)
  "View the pod synopsis for a Bioperl module."
  (interactive
   (let (
	 (mod (bioperl-completing-read (bioperl-module-at-point) nil t "[pod syn] "))
	 )
     (if (not (member nil (mapcar 'not mod))) (signal 'quit t))     
     (list (apply 'concat 
		  (elt mod 0) 
		  (if (elt mod 1) (list "::" (elt mod 1)) 
		    (signal 'quit t) )))))
  (bioperl-view-pod-section module "SYNOPSIS"))

(defun bioperl-view-pod-description (module)
  "View the pod synopsis for a BioPerl module."
  (interactive
   (let (
	 (mod (bioperl-completing-read (bioperl-module-at-point) nil t "[pod dsc] " ))
	 )
     (if (not (member nil (mapcar 'not mod))) (signal 'quit t))     
     (list (apply 'concat 
		  (elt mod 0) 
		  (if (elt mod 1) (list "::" (elt mod 1)) 
		    (signal 'quit t))))))
  (bioperl-view-pod-section module "DESCRIPTION"))

(defun bioperl-view-pod-appendix (module)
  "View the pod appendix (containing individual method information) for a Bioperl module."
  (interactive
   (let (
	 (mod (bioperl-completing-read (bioperl-module-at-point) nil t "[pod apx] "))
	 )
     (if (not (member nil (mapcar 'not mod))) (signal 'quit t)) 
     (list (apply 'concat 
		  (elt mod 0) 
		  (if (elt mod 1) (list "::" (elt mod 1)) 
		    (signal 'quit t))))))
  (bioperl-view-pod-section module "APPENDIX"))

;; "uninstall..."

(defun bioperl-mode-unload-hook &optional local
  "Remove the perl-mode hook.
If LOCAL is set, remove hook from the buffer-local value of perl-mode-hook."
  (remove-hook 'perl-mode-hook 'bioperl-perl-mode-infect local))

;;
;; Internal functions
;;

;;
;; list getters
;;

(defun bioperl-method-names (module &optional as-alist n) 

  "Returns a list of method names as given in the pod of MODULE. 
MODULE is in double-colon format. If AS-ALIST is t, return an
alist with elts as (NAME . nil). N is an index associated with a 
component of `bioperl-module-path'.

This function looks first to see if methods for MODULE are
already loaded in `bioperl-method-pod-cache'; if not, calls
`bioperl-slurp-methods-from-pod'."
  (unless (stringp module) 
    (error "String required at arg MODULE"))
  (unless (bioperl-path-from-perl module nil n)
    (error "Module specified by MODULE not found in installation"))
  ;; check the cache; might get lucky...
  (let ( (ret) ) 
    (setq ret 
	  (if (string-equal module bioperl-cached-module)
	      (progn
		(mapcar 'car bioperl-method-pod-cache)
		;; path handling...
		)
	    (mapcar 'car (bioperl-slurp-methods-from-pod module n)))) 
    ;; fix alist for path handling??
    (if as-alist
	(mapcar (lambda (x) (list x nil)) ret)
      ret)))


(defun bioperl-module-names (module-dir &optional retopt as-alist)
  "Returns a list of modules contained in the directory indicated by MODULE-DIR.
MODULE-DIR is in double-colon format.  Optional RETOPT: nil,
return module names only (default); t, return directory names
only; other, return all names as a flat list. Optional AS-ALIST:
if t, return an alist with elts (NAME . PATH_STRING) (when used in 
completing functions, for back-compat with Emacs 21).

 This function is responsible for the lazy loading of the module
names cache: it will look first in `bioperl-module-names-cache'; if
the MODULE-DIR is not available,
`bioperl-add-module-names-to-cache' will be called."
  (let* (
	(module-components (split-string module-dir "::"))
	(unlist (lambda (x) (if (listp x) (car x) x)) )
	(choose-dirs (lambda (x) (if (listp (cdr x)) x nil)) )
	(choose-mods  (lambda (x) (if (listp (cdr x)) nil x)) )
	(ret)
	(alists (deep-assoc-all module-components bioperl-module-names-cache))
	(alist)
	)
    ;; here pick the directory alist
    (if (listp (cdr (car alists)))
	(setq alist (car alists))
      (setq alist (elt alists 1)))
    
    (if (and alist (cdr alist))
	(cond 
	 ( (not (booleanp retopt))
	   (if (stringp (cdr alist))
	       (setq ret alist)
	     (setq ret (cdr alist))))
	 ((not retopt)
	   (if (stringp (cdr alist))
	       (setq ret alist)
	     (setq ret (delete nil (mapcar choose-mods (cdr alist))))
	     ))
	 ( retopt
	   (if (stringp (cdr alist))
	       (setq ret nil)
	     (setq ret (delete nil (mapcar choose-dirs (cdr alist))))
	     )))
      (if (bioperl-add-module-names-to-cache module-dir)
	  (cond
	   ( (not (booleanp retopt))
	     (setq ret
		   (cdr (deep-assoc module-components bioperl-module-names-cache)))) 
	   ((not retopt)
	    (setq ret
		  (delete nil (mapcar choose-mods
			  (cdr (deep-assoc module-components bioperl-module-names-cache))))))
	   ( retopt
	     (setq ret
		   (delete nil (mapcar choose-dirs
			  (cdr (deep-assoc module-components bioperl-module-names-cache))))))
	nil)))
    (if (not as-alist) 
	(if (stringp (cdr ret))
	    (car ret)
	  (mapcar 'car ret))
      ret)))


;;
;; pod slurpers
;;

(defun bioperl-view-full-pod (module &optional n) 
  "Open the Bioperl POD for the MODULE for viewing in another buffer.
MODULE is in double-colon format."
  (unless bioperl-system-pod2text 
    (unless (bioperl-find-system-pod2text)
      (error "Can't find pod2text; try setting bioperl-system-pod2text manually")))
  (unless (bioperl-check-system-pod2text)
    (error "Unexpected command in bioperl-system-pod2text; aborting..."))
  (unless (and module (stringp module))
    (error "String required at arg MODULE"))
  (unless (or (not n) (numberp n))
    (error "Number required at arg N"))
  (unless n
    (setq n 0))
  (if (not module)
      nil
    (let (
	  (old-exec-path exec-path)
	  (pod-buf (generate-new-buffer "*BioPerl POD*"))
	  (pmfile (bioperl-path-from-perl module nil n))
	  (args bioperl-pod2text-args)
	  )
      (unless pmfile
	(error "Module specified by MODULE not found in installation"))
      ;; safe path
      (if bioperl-mode-safe-flag
	  (setq exec-path bioperl-safe-PATH))
      ;; untaint pod2text args
      (setq args (remove 
		  nil 
		  (mapcar (lambda (x) (and (string-match "^[-].$" x) x)) 
			  args)))
      (save-excursion
	(set-buffer pod-buf)
	(setq header-line-format (concat "POD - BioPerl module " module))
	(apply 'call-process bioperl-system-pod2text
	       nil t t pmfile args)
	(goto-char (point-min))
	(bioperl-view-mode)
	(pop-to-buffer pod-buf))
      ;; restore old exec-path
      (setq exec-path old-exec-path)
      )
    ;;return val
    t ))

(defun bioperl-view-pod-section (module section &optional n)
  "Open the Bioperl POD for the module PMFILE for viewing in another buffer.
MODULE is in double-colon format. SECTION is a string; one of
SYNOPSIS, DESCRIPTION, or APPENDIX. N is the index of the desired
component of bioperl-module-path."
  (unless bioperl-system-pod2text 
    (unless (bioperl-find-system-pod2text)
      (error "Can't find pod2text; try setting bioperl-system-pod2text manually")))
  (unless (bioperl-check-system-pod2text)
    (error "Unexpected command in bioperl-system-pod2text; aborting..."))
  (unless (stringp module)
    (error "String required at arg MODULE"))
  (unless (stringp section) 
    (error "String required at arg SECTION"))
  (unless (member (upcase section) '("SYNOPSIS" "DESCRIPTION" "APPENDIX"))
    (error "SECTION not recognized or handled yet"))
  (unless (or (not n) (numberp n))
    (error "Number required at arg N"))
  (unless n
    (setq n 0))
  (let (
	(pod-buf (generate-new-buffer "*BioPerl POD*"))
	(args '("-a"))
	(ret nil)
	(pmfile (bioperl-path-from-perl module nil n))
	(old-exec-path exec-path)
	)
    (unless pmfile
      (error "Module specified by MODULE not found in installation"))
    ;; safe path
    (if bioperl-mode-safe-flag
	(setq exec-path bioperl-safe-PATH))
    (save-excursion
      (set-buffer pod-buf)
      (setq header-line-format (concat section " - BioPerl module " module))
      (apply 'call-process bioperl-system-pod2text
				  nil t t pmfile args)
      (goto-char (point-min))
      ;; clip to desired section
      (if (search-forward (concat "== " section) (point-max) t)
	  (progn
	    (beginning-of-line)
	    (delete-region (point-min) (point))
	    (forward-line 1)
	    (search-forward "====" (point-max) 1)
	    (beginning-of-line)
	    (delete-region (point) (point-max))
	    (goto-char (point-min))
	    (bioperl-view-mode)
	    (pop-to-buffer pod-buf)
	    (setq ret t))
	(kill-buffer pod-buf)
	)
	;; restore old exec-path
	(setq exec-path old-exec-path)
    )
    ret ))


(defun bioperl-slurp-methods-from-pod (module &optional n) 
  "Parse pod for individual methods for module MODULE.
MODULE is in double-colon format. N is an index corresponding 
to a component of `bioperl-module-path'.

Returns an associative array of the following form:

 ( METHOD_NAME . ( (PODKEY . CONTENT) (PODKEY . CONTENT) ... )
   METHOD_NAME . ( (PODKEY . CONTENT) (PODKEY . CONTENT) ... )
   ... )

where all elements are strings. The alist is sorted by
METHOD_NAME. METHOD_NAME is the name of the method (without
trailing parens), PODKEY is 'Title', 'Usage', 'Function',
'Returns', 'Args' (these keys are read directly from pod and not
standardized), CONTENT is the text that follows the colon
separating the PODKEY heading from the information (including all
text up until the next 'PODKEY :' line. Newlines are converted to
';' in the content, and whitespace is squished to single
spaces/semicolons.

This function, when successful, also sets the cache vars
`bioperl-method-pod-cache' and `bioperl-cached-module'."
  (unless (stringp module) 
    (error "String required at arg MODULE"))
  (unless bioperl-system-pod2text
    (unless (bioperl-find-system-pod2text)
      (error "pod2text path not set yet; you can set bioperl-system-pod2text manually or call bioperl-find-system-pod2text")))
  (unless (bioperl-check-system-pod2text)
    (error "Unexpected command in bioperl-system-pod2text; aborting..."))
  (let (
	(pmfile (bioperl-path-from-perl module nil n))
	)
    (unless pmfile
      (error (concat "Module specified by MODULE not found in installation at path component " (number-to-string (if n n 0)) ".\nCheck contents of `bioperl-module-path' and call `bioperl-clear-names-cache'.") ))
    (let (
	(method nil)
	(pod-key nil)
	(content nil)
	(bound nil)
	(data '())
	(data-elt '())
	(data-elt-cdr '())
	(old-exec-path exec-path)
	)
    ;; safe path
      (if bioperl-mode-safe-flag
	  (setq exec-path bioperl-safe-PATH))
      (with-temp-buffer
	(if (not (= 0
		    (call-process bioperl-system-pod2text
				  nil t t pmfile "-a")))
	    (error "pod2text failed"))
	;; clip to desired section
	(goto-char (point-min))
	(if (search-forward "= APPENDIX" (point-max) t)
	    (progn
	      (beginning-of-line)
	      (delete-region (point-min) (point))
	      ;; looking down into appendix
	      ;; 
	      (while (re-search-forward "^==\\s +\\([a-zA-Z0-9_]+\\)" 
					(point-max) t)
		(setq method (match-string 1))
		(setq data-elt (cons method '()))
		;; now we have the current method...
		;; find the boundary of this method's pod
		(save-excursion
		  (setq bound (progn (re-search-forward "^=" 
							(point-max) 1)
				     (beginning-of-line)
				     (point))))
		;; now parse out the guts of this method's pod
		;; getting pod-keys and their content...
		(while (re-search-forward 
			"^\\s +\\([A-Za-z]+\\)\\s *:\\s *\\(.*\\)$"
			bound t)
		  (setq pod-key (match-string 1))
		  (setq content (match-string 2))
		  (save-excursion 
		    (setq content 
			  (concat content 
				  (buffer-substring 
				   (point) (if (re-search-forward "^\\s +[A-Za-z]+\\s *:" bound 1)
					       (progn (beginning-of-line) (point))
					     (point)))))
		    )
		  ;; squeeze whitespace from content
		  (setq content (replace-regexp-in-string "\n+" "!!" content))
		  (setq content (replace-regexp-in-string ";$" "" content))
		  (setq content (replace-regexp-in-string "\\s +" " " content))
		;; here we have, for the current method,
		  ;; the current pod-key and its content...
		  (setq data-elt-cdr (cdr data-elt))
		  (setcdr data-elt (push (cons pod-key content) data-elt-cdr )))
		;; copy the data-elt into the data alist...
		(setq data-elt-cdr (cdr data-elt))
		(push (cons (car data-elt) data-elt-cdr) data))
	      ;; set cache vars
	      (setq bioperl-method-pod-cache 
		    (sort data (lambda (a b) (string-lessp (car a) (car b)))))
	      (setq bioperl-cached-module module)
	      ;; return the data alist for this module...
	      bioperl-method-pod-cache )
	  ;; the APPENDIX was not found...return nil
	  nil ) ))))

;;
;; directory slurpers
;;

(defun bioperl-add-module-names-to-cache (module-dir &optional n)
  "Add alists to `bioperl-module-names-cache'.
MODULE-DIR is in double colon format. Allows for lazy build of
the cache.  Returns t if we added anything, nil if not. N is the index
of the desired bioperl-module-path component.

Cache alist format:
 ( \"Bio\" . 
   ( (MODULE_NAME PATH_INDEX_STRING) ...        ; .pm file base names
     (DIRNAME . nil) ...           ; dirname read but not yet followed
     (DIRNAME . ( ... ) ) ... )    ; dirname assoc with >=1 level structure
 )	      
"				     
 
  (unless (and module-dir (stringp module-dir))
    (error "String required at arg MODULE-DIR"))
  (unless (or (not n) (numberp n))
    (error "Number required at arg N"))
  (unless n
    (setq n 0))
  (if (and (> n 0) (> n (1- (length (split-string bioperl-module-path path-separator)))))
      (error "Path index out of bounds at arg N"))
  (let* (
	(pth (bioperl-path-from-perl module-dir 1 n))
	(module-components (split-string module-dir "::"))
	(module-string nil)
	(modules nil)
	(cache (deep-assoc-all module-components bioperl-module-names-cache))
	(cache-pos nil)
	(keys nil)
	(this-key nil)
	(good-keys nil)
	(ret nil)
       )
    (if (not pth)
	;; no path returned for module-dir...
	nil
      (setq cache-pos 
	    (cond
	     ((not cache)
	      nil)
	     ((stringp (cdr (car cache)))
	      (elt cache 1))
	     ( t
	       (elt cache 0))))
      (if cache-pos ;; something there
	  ;; easy - a stub
	  (if (null (cdr cache-pos))
	      (progn 
		(setcdr cache-pos (bioperl-slurp-module-names module-dir n))
		(setq ret t))
	      ;; less hard - branch exists
	    (let* ( 
		   (mod-alist (bioperl-slurp-module-names module-dir n))
		   (mod-alist-keys (mapcar 'car mod-alist))
		   (cache-item) (key)
		   )
	      (while (setq key (pop mod-alist-keys))
		(setq cache-item (assoc key cache-pos))
		(if (null cache-item)
		    nil
		  (if (member n (split-string (cdr cache-item) path-separator))
		      ;; deja vu
		      (setq mod-alist-keys nil) ;; fall-through
		    (setcdr cache-item (concat (cdr (assoc key mod-alist)) path-separator (cdr cache-item)))
		    (setq ret t))))
	      ))

	;; hard - branch dne
	(setq keys module-components)
	(while (
		let ( (da (deep-assoc-all 
			   (append good-keys (list (car keys))) 
			   bioperl-module-names-cache) ) )
		 (setq da (car (delete nil
				       (mapcar (lambda (x) 
						 (if (listp (cdr x)) x nil)) 
					       da))))
		 (car da) );; has a member whose cdr is a list 
	  (setq good-keys (append good-keys (list (car keys))))
	  (setq keys (cdr keys)))
	;; keys contains the directories we need to add, in order
	;; address for doing additions: cache-pos
	(setq cache-pos (deep-assoc good-keys bioperl-module-names-cache))
	(setq module-string (pop good-keys))
	(while good-keys
	  (setq module-string (concat module-string "::" (pop good-keys))))
	;; module-string is suitable for passing to bioperl-slurp-module-names
	
	;; move down the module directory, slurping up methods and placing
	;; in cache
	(while keys 
	  (setq this-key (pop keys))
	  (setq module-string (if module-string (concat module-string "::" this-key) this-key))
	  (setq modules (bioperl-slurp-module-names module-string n))
	  (if (not modules)
	      (setq keys nil)
	    (setq ret t)
	    (if cache-pos
		(progn
		  (setcdr cache-pos (append (cdr cache-pos)  (list (cons this-key modules))))
		  (setq cache-pos (assoc this-key cache-pos)))
	      (setq bioperl-module-names-cache (list (cons this-key modules)))
	      (setq cache-pos (assoc this-key bioperl-module-names-cache)))
	    )))
      )
    ret ))

(defun bioperl-slurp-module-names (module-dir &optional n)
  "Return list of the  basenames for .pm files contained in MODULE-DIR.
MODULE-DIR is in double-colon format. N is the index of the desired 
bioperl-module-path component.

Return is a list of the form

 ( (MODULE_NAME . PATH_INDEX_STRING) ... 
   (DIR_NAME . nil) ... )
"
  (unless (and module-dir (stringp module-dir))
    (error "String required at arg MODULE-DIR"))
  (unless (or (not n) (numberp n))
    (error "Number required at arg N"))
  (unless n
    (setq n 0))
  (let (
	(module-path (elt (split-string bioperl-module-path path-separator) 0))
	(pth (bioperl-path-from-perl module-dir 1 n))
	(modules nil)
	(fnames nil)
       )
    (if (and (> n 0) (> n (1- (length module-path))))
	(error "Path index out of bounds at arg N"))
    ;; following (elt ... 0) checks if pth is dir or symlink
    ;; possible bug...
    ;; try including directory names too, as (list (cons name nil))
    ;; stubs for descending into those later...
    (if (and pth (elt (file-attributes pth) 0))
	(progn
	  (setq fnames (directory-files pth))
	  (while fnames 
	    (let ( (str (pop fnames)))
	      ;; files - conses with path-index cdr
	      (if (string-match "\\([a-zA-Z0-9_]+\\)\.pm$" str)
		  (push (cons (match-string 1 str) (number-to-string n))  modules))
	      ;; directories - conses with nil cdr
	      (if (string-match "^\\([a-zA-Z0-9_]+\\)$" str)
		  (if (not (string-equal (match-string 1 str) "README")) (push (cons (match-string 1 str) nil) modules)))
	      ))
	  (if (not modules)
	      nil
	    modules))
      nil)))

;;
;; string converters and finders
;;

(defun bioperl-module-at-point ()
  "Look for something like a module identifier at point, and return it."
  (interactive)
  (let (
	(found (thing-at-point-looking-at "Bio::[a-zA-Z_:]+"))
	(module nil)
	(pth nil)
	)
    (if (not found) 
	nil
      (setq module (apply 'buffer-substring (match-data)))
      module)))

(defun bioperl-find-module-at-point (&optional n)
  "Look for something like a module declaration at point, and return a filepath corresponding to it.
N is the index of the desired bioperl-module-path component."
  (interactive)
  (unless (or (not n) (numberp n))
    (error "Number required at arg N"))
  (unless n
    (setq n 0))
  (unless bioperl-module-path
      (error "bioperl-module-path not yet set; you can set it with bioperl-find-module-path"))
  (let ( 
	(module-path (elt (split-string bioperl-module-path path-separator) n))
	(found) (module) (pth)
	)
    (if (and (> n 0) (> n (1- (length module-path))))
	(error "Path index out of bounds at arg N"))
    (unless (file-exists-p (concat module-path "/Bio"))
      (error (concat "Bio modules not present in path component" module-path )))
    (setq found (thing-at-point-looking-at "Bio::[a-zA-Z_:]+"))
    (if (not found) 
	nil
      (setq module (apply 'buffer-substring (match-data)))
      (setq pth (bioperl-path-from-perl module n)))
    pth))


(defun bioperl-path-from-perl (module &optional dir-first n) 
  "Return a path to the module file represented by the perl string MODULE.
Returns nil if no path found. If DIR-FIRST is t, return a
directory over a .pm file if there is a choice. If DIR-FIRST is
not t or nil, return a directory only. N is an integer, indicating the
desired member of bioperl-module-path to search."
  (unless bioperl-module-path
    (error "bioperl-module-path not yet set; you can set it with bioperl-find-module-path"))
  (unless (stringp module)
    (error "string arg required at MODULE"))
  (unless (or (not n) (numberp n))
    (error "number arg required at N"))
  ; default
  (unless n
    (setq n 0))
  (let (
	(module-path (elt (split-string bioperl-module-path path-separator) n))
	(module-components (split-string module "::"))
	(pth)
	(dir (if (not (boundp 'dir-first)) nil dir-first))
	)
    (if (and (> n 0) (> n (1- (length module-path))))
	(error "Path index out of bounds at arg N"))
    (unless (file-exists-p (concat module-path "/Bio"))
      (error (concat "Bio modules not present in path component " module-path)))
    (setq module-components (split-string module "::"))
    ;; unixize...
    (setq pth (replace-regexp-in-string "\\\\" "/" module-path))
    
    (while (not (null module-components))
      (setq pth (concat pth "/" (car module-components)))
      (setq module-components (cdr module-components)))
    (if (not (booleanp dir))
	(if (file-exists-p pth)
	    t
	  (setq pth nil))
      (if (and dir (file-exists-p pth))
	  t
	(if (file-exists-p (concat pth ".pm"))
	    (setq pth (concat pth ".pm"))
	  (if (file-exists-p pth)
	      t
	    (setq pth nil)))))
    pth))

(defun bioperl-split-name (module &optional dir-first n)
  "Examine MODULE and return a list splitting the argument into an existing namespace and module name.
MODULE is in double-colon format. This checks existence as well,
and returns nil if no split corresponds to an existing file. The
algorithm uses `bioperl-path-from-perl' to do its tests.  Default
behavior is to return (namespace module) if there is a choice.
If DIR-FIRST is t, return (namespace nil) over (namespace module)
if there is a choice. If DIR-FIRST is not t or nil, return only
\(namespace nil) or nil.

Finally, if the namespace portion of MODULE exists, but the module
specified by MODULE does not, (namespace nil) is returned.
N specifies the index of the desired bioperl-module-path component. "

  (unless (or (not module) (stringp module))
    (error "String arg required at MODULE"))
  (unless (or (not n) (numberp n))
    (error "Number required at arg N"))
  (unless n
    (setq n 0))
  (if (not module)
      (list nil nil)
    (if (not (string-match "^Bio" module))
	nil
      ( let (
	     (module-path (elt 
			   (split-string bioperl-module-path path-separator) n))
	     (nmspc) (mod) (pmfile) 
	     )
	(if (and (> n 0) (> n (1- (length module-path))))
	    (error "Path index out of bounds at arg N"))
	(if (not (string-match "::\\([a-zA-Z0-9_]+\\)$" module))
	    (setq nmspc module)
	  (setq mod (match-string 1 module))
	  (setq nmspc (substring module 0 (- (match-beginning 1) 2))))
	(cond
	 ( (not (booleanp dir-first))
	   (if (bioperl-path-from-perl module dir-first n)
	       (list module nil)
	     (list (concat "*" module) nil)) )
	 ( t 
	   (setq pmfile (bioperl-path-from-perl module dir-first n))
	   (if pmfile
	       (if (string-match "\.pm$" pmfile)
		   (list nmspc mod)
		 (list module nil))
	     (if dir-first
		 (progn (setq nmspc (concat nmspc "::" mod))
			(setq mod nil)))
	     (if (bioperl-path-from-perl nmspc 1 n)
		 (list nmspc (concat "*" mod))
	       (list (concat "*" nmspc) nil))
	     ))) 
	))))

(defun bioperl-render-method-pod-from-cons (cons)
  "Create a view buffer containing method pod using a member of the `bioperl-method-pod-cache' alist.

CONS has the form 

 ( METHOD_NAME . ( ( POD_TAG . CONTENT) (POD_TAG . CONTENT) ... ) ). 

The module name for this method is assumed to be present in
`bioperl-cached-module'"
  (unless (listp cons)
    (error "List required at arg CONS"))
  (if (not cons) 
      nil
    (let* ( 
	  (module bioperl-cached-module)
	  (method (car cons))
	  (content (cdr cons))
	  ;; reverse below is a sort-of kludge
	  (tags (if content (reverse (mapcar 'car content)) nil))
	  (cur-tag nil)
	  (cur-content nil)
	  (pod-buf (generate-new-buffer "*BioPerl POD*"))
	  )
      (if (not content)
	  (message "No pod available")
	(save-excursion
	  (set-buffer pod-buf)
	  ;; nice header
	  (setq header-line-format (concat "Method " method "() - BioPerl module " module))
	  (insert "\n")
	  (while (setq cur-tag (pop tags))
	    (setq cur-content (cdr (assoc cur-tag content)))
	    (setq cur-content (replace-regexp-in-string "!!" "\t\n" cur-content))
	    (insert cur-tag " : " cur-content))
	  (goto-char (point-min))
	  (bioperl-view-mode)
	  (pop-to-buffer pod-buf)))
      )))

;; 
;; completion tricks
;;

(defun bioperl-completing-read (initial-input &optional get-method dir-first prompt-prefix no-retry)
  "Specialized completing read for bioperl-mode.
INITIAL-INPUT is a namespace/module name in double-colon format,
or nil. Returns a list: (namespace module path-string) if GET-METHOD is nil,
\(namespace module method path-string) if GET-METHOD is t. DIR-FIRST is
passed along to `bioperl-split-name'; controls what is returned
when a namespace name is also a module name (e.g., Bio::SeqIO).
If NO-RETRY is nil, the reader works hard to return a valid entity;
if t, the reader barfs out whatever was finally entered."
  (let ( (parsed (bioperl-split-name initial-input dir-first)) 
	 (nmspc) (mod) (mth) (pthn) (name-list)
	 (done nil))
    (if (not parsed)
	nil
      (setq nmspc (elt parsed 0))
      (setq mod (elt parsed 1)))
    (while (not done)
      ;; namespace completion
      (unless (and nmspc (not (string-match "^\*" nmspc)))
	(cond 
	 ( (not nmspc) nil )
	 ( (string-match "^\*" nmspc)
	   (setq initial-input (replace-regexp-in-string "^\*" "" nmspc))))
	(setq nmspc (completing-read 
		     (concat prompt-prefix "Namespace: ")
		     'bioperl-namespace-completion-function
		     nil (not no-retry) (or initial-input "Bio::")) )
	(if (not (string-equal nmspc ""))
	    t
	  ;; back up
	  (setq nmspc (car (split-string nmspc "::[^:]+$")))
	  (setq done nil)))
      ;; module completion
      (if (or (not nmspc)
		  (and mod (not (string-match "^\*" mod))))
	  (setq done t)
	(let (
	      ;; local vars here
	      )
	  (setq name-list (bioperl-module-names nmspc nil t))
	  (setq mod (completing-read 
		     (concat prompt-prefix nmspc " Module: ")
		     name-list nil (not no-retry)
		     (if mod (replace-regexp-in-string "^\*" "" mod) nil)))
	  ;; allow a backup into namespace completion
	  (if (or no-retry (not (string-equal mod "")))
	      (setq done t)
	    ;; retry setup
	    ;; try again, backing up
	    (setq done nil)
	    (let ( (splt (bioperl-split-name nmspc nil)) )
	      (if (elt splt 1)
		  (progn
		    (setq nmspc (elt splt 0))
		    ;; kludge : "pretend" mod is not found using the "*"
		    (setq mod (concat "*" (elt splt 1))))
		(setq nmspc (concat "*" nmspc))
		(setq mod nil)))
	    (setq initial-input nmspc))))
      ;; path completion
      (unless (or (not (and nmspc mod)) (not done))
	(if (not name-list)
	  (setq name-list (bioperl-module-names 
			   nmspc nil t)))
	(setq pthn (cdr (assoc mod name-list)))
	(if (not pthn) 
	    (error "Shouldn't be here. Check `bioperl-module-path' and try running `bioperl-clear-module-cache'."))
	(if (not (string-match path-separator pthn))
	    ;; single path 
	    (setq pthn (string-to-number pthn))
	  ;; multiple paths (e.g., "0;1") - do completion
	  (let* (
		 (module-path 
		  (split-string bioperl-module-path path-separator))
		 (pthns (mapcar 'string-to-number
				(split-string pthn path-separator)))
		 (i -1)
		 (module-path-list 
		  (mapcar 
		   (lambda (x) (setq i (1+ i)) (list x i) )
		   module-path))
		 )
	    ;; filter list by pthns
	    (setq module-path-list
		  (delete nil (mapcar 
			       (lambda (x) (if (member (elt x 1) pthns) x nil))
			       module-path-list)))
	    (if (not module-path-list)
		(error "Shouldn't be here. Run `bioperl-clear-module-cache' and try again"))
	    (setq pthn (completing-read 
			(concat prompt-prefix "Lib: ")
			module-path-list
			nil t (car (car module-path-list))))
	    (if (string-equal pthn "")
		(setq pthn (car (car module-path-list))))
	    (setq pthn (elt (assoc pthn module-path-list) 1))
	    )))
      ;; method completion
      (unless (or (not done) (not (and nmspc mod)) (not get-method))
	;; path completion if necessary
	(if pthn
	    t
	  (setq pthn (cdr (bioperl-module-names nmspc nil t)))
	  (if (not (string-match path-separator pthn))
	      ;; single path
	      (setq pthn (string-to-number pthn))
	    ;; multiple paths (e.g., "0;1") - do completion
	    (let* (
		   (module-path 
		    (split-string bioperl-module-path path-separator))
		   (pthns (mapcar 'string-to-number
				  (split-string pthn path-separator)))
		   (i -1)
		   (module-path-list 
		    (mapcar 
		     (lambda (x) (setq i (1+ i)) (list x i) )
		     module-path))
		   )
	      ;; filter list by pthns
	      (setq module-path-list
		    (delete nil (mapcar 
				 (lambda (x) (if (member (elt x 1) pthns) x nil))
				 module-path-list)))
	      (if (not module-path-list)
		  (error "Shouldn't be here. Run `bioperl-clear-module-cache' and try again"))
	      (setq pthn (completing-read 
			  (concat prompt-prefix "Lib: ")
			  module-path-list
			nil t (car (car module-path-list))))
	      (if (string-equal pthn "")
		  (setq pthn (car (car module-path-list))))
	      (setq pthn (elt (assoc pthn module-path-list) 1))
	      )
	    ))
	(setq name-list (bioperl-method-names (concat nmspc "::" mod) nil pthn))
	(let (
	      ;; local vars here...
	      )
	  (setq mth (completing-read
		     (concat prompt-prefix "Method in " nmspc "::" mod ": ")
		     name-list nil (not no-retry)))
	  (if (or no-retry (not (string-equal mth "")))
	      (setq done t)
	    ;; retry setup
	    ;; allow a backup into module completion
	    (setq done nil)
	    (let ( 
		  (splt (bioperl-split-name (concat nmspc "::" mod) nil pthn))
		  )
	      (setq nmspc (elt splt 0))
	      ;; kludge : "pretend" mod is not found using the "*"
	      (setq mod (concat "*" (elt splt 1))))))
	))
    ;; return values
    (if get-method
	(list nmspc mod mth pthn)
      (list nmspc mod pthn)) ))

(defun bioperl-namespace-completion-function (str pred flag)
  "A custom completion function for bioperl-mode.
Allows the lazy build of the `bioperl-module-names-cache'."
  (if (not pred) 
      (setq pred 
	    (lambda (x) (setq x (if (listp x) (car x) x) ) (if (string-match "[a-zA-Z0-9_:]+" x) t nil))
	    ))
  (let (
	( collection (if (string-equal str "") '(("Bio" . nil )) (bioperl-make-collection str t)) )
	)
    ;; offer the right collection:
    ;; if collection was set, the str was complete and valid
    ;; if not, back up to the last :: in str (see str-trunc in above
    ;; let) and try again
   
    (if (not collection) 
	nil
      (setq collection (sort collection (lambda (x y) (string< (car x) (car y)))))
      (cond
       ((not (booleanp flag)) ;; 'lambda' or test-completion option
	;; this is a back-compat issue: emacs 21 will send 'lambda', 
	;; but doesn't have 'test-completion
	;;
	;; Note without test-completion, weird completion bugs can crop
        ;; up -- best upgrade to 22--
	(if (condition-case nil
		(symbol-function 'test-completion)
	      ('error nil))
	    (test-completion str collection pred)
	  collection
	  (try-completion str collection pred))
	)
       ( (not flag) ;; try-completion option
	   (try-completion str collection pred)
	   )
       ( flag ;; all-completion option
	   (all-completions str collection pred)
	   )
       ))))

(defun bioperl-make-collection (module-dir &optional retopt)
  "Create a completion collection for MODULE-DIR.
MODULE-DIR is in double-colon format, possibly with two trailing
colons.  RETOPT is as for `bioperl-module-names'."
  ;; handle the boundary
  (if (or (not module-dir) (not (string-match ":" module-dir)))
      '("Bio::")
    (setq module-dir (progn (string-match "^\\([a-zA-Z0-9_:]+[^:]\\):*$" module-dir)
			    (match-string 1 module-dir)))
    (let* (
	   ( dirs (bioperl-module-names module-dir retopt t) )
	   ( modules (split-string module-dir "::") )
	   ( complet ) 
	   )
      ;; check once and recalc
      (if (not dirs)
	  (progn 
	    ;; trim back to last ::
	    (setq module-dir
		  (progn 
		    (string-match  "^\\(\\(?:[a-zA-Z0-9_]+::\\)+\\)\\(?::*\\|[a-zA-Z0-9_]*\\)$" str) 
		    (match-string 1 str)))
	    (setq dirs (bioperl-module-names module-dir retopt t))
	    (setq modules (split-string module-dir "::"))
	    ))
      (if (not dirs)
	  ;; fail
	  nil
	(setq complet (let* ( (l modules)
			      (m (list (pop l))) )
			(while l (push (concat (car m) "::" (pop l)) m))
			(mapcar (lambda (x) (cons x nil)) m ) ))
	;; make sure module-dir is trimmed
	(setq module-dir (replace-regexp-in-string "::$" "" module-dir))
	complet
	(append complet (mapcar (lambda (x) 
				  (list
				   (concat module-dir "::" (car x)) 
				   (cdr x))) dirs))
	))
      ))

;;
;; utilities
;;

(defun bioperl-clear-module-cache ()
  (interactive)
  "Clears the variable `bioperl-module-names-cache'. Run if you change `bioperl-module-path'."
  (setq bioperl-module-names-cache nil))

;;
;; taint checkers
;;

(defun bioperl-check-system-pod2text ()
  "See if `bioperl-system-pod2text' is naughty."
  (if (and bioperl-system-pod2text (string-match "pod2text\\(\\|\\.bat\\|\\.exe\\)$" bioperl-system-pod2text))
      t
    nil))

;;
;; utilities (out of bioperl- namespace)
;;

    
(defun assoc-all (key alist &optional ret)
  "Return list of *pointers* (like assoc) to all matching conses in the alist."
  (let ( (c (assoc key alist)) (r) ) 
    (if c 
	(assoc-all key (cdr alist) (if ret (add-to-list 'ret c t 'eq) (list c)))
      ret)))

(defun deep-assoc (keys alist)
  "Return the associations of a set of keys in an alist tree."
  (cond
   ((not keys) 
    nil)
   ((not (listp alist))
    nil)
   ((= (length keys) 1)
    (assoc (pop keys) alist))
   (t
    (let* ( (key (pop keys))
	    (newlist (assoc key alist)) ) 
      (if newlist
	  (deep-assoc keys (cdr newlist))
	(deep-assoc nil nil)))
    )))

(defun deep-assoc-all (keys alist)
  "Return all associations AT THE TIP described by the set of KEYS in an alist tree.
So this is not completely general, but is specialized to the structure of `bioperl-module-names-cache'."
  (cond
   ((not keys) 
    nil)
   ((not (listp alist))
    nil)
   ((= (length keys) 1)
    (assoc-all (pop keys) alist))
   (t
    (let* ( (key (pop keys))
	    (newlist (assoc-all key alist)) ) 
      (if newlist
	  (let ( ( i 0 ) (r)  )
	    (while (< i (length newlist))
	      (if (listp (cdr (elt newlist i)))
		  (setq r (deep-assoc-all keys (cdr (elt newlist i)))))
	      (setq i (1+ i)))
	    r)
	(deep-assoc-all nil nil)))
    )))


(defun pm-p (x)
  (not (null (string-match "[.]pm\$" x))))

;; hook into perl-mode

(add-hook 'perl-mode-hook 'bioperl-perl-mode-infect)

(provide 'bioperl-mode)

;;; end bioperl-mode.el
  
  
;;
;; scratch area
;;
(unless nil






)
