;; $Id$

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
On init, set is attempted by `bioperl-find-module-path'"
  :type 'file
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

(defun bioperl-method-names (module) 

  "Returns a list of method names as given in the pod of MODULE. MODULE is in double-colon format.

This function looks first to see if methods for MODULE are
already loaded in `bioperl-method-pod-cache'; if not, calls
`bioperl-slurp-methods-from-pod'."
  (unless (stringp module) 
    (error "String required at arg MODULE"))
  (unless (bioperl-path-from-perl module)
    (error "Module specified by MODULE not found in installation"))
  ;; check the cache; might get lucky...
  (if (string-equal module bioperl-cached-module)
      (mapcar 'car bioperl-method-pod-cache)
    (mapcar 'car (bioperl-slurp-methods-from-pod module))))


(defun bioperl-module-names (module-dir &optional retopt)
  "Returns a list of modules contained in the directory indicated by MODULE-DIR.
MODULE-DIR is in double-colon format.  Optional RETOPT: nil,
return module names only (default); t, return directory names
only; other, return all names as a flat list.

 This function is responsible for the lazy loading of the module
names cache: it will look first in `bioperl-module-names-cache'; if
the MODULE-DIR is not available,
`bioperl-add-module-names-to-cache' will be called."
  (let (
	(module-components (split-string module-dir "::"))
	(alist nil)
	)
    (setq alist (deep-assoc module-components bioperl-module-names-cache))
    (if (and alist (cdr alist))
	(cond 
	 ( (not (booleanp retopt)) 
	   (mapcar (lambda (x) (if (listp x) (car x) x)) 
		   (cdr alist)))
	 ((not retopt)
	  (delete nil (mapcar 
		       (lambda (x) (if (listp x) nil x)) 
		       (cdr alist))))
	 ( retopt
	  (delete nil (mapcar 
		       (lambda (x) (if (listp x) (car x) nil)) 
		       (cdr alist)))))
      (if (bioperl-add-module-names-to-cache module-dir)
	  (cond
	   ( (not (booleanp retopt))
	     (mapcar 
	      (lambda (x) (if (listp x) (car x) x)) 
	      (cdr (deep-assoc module-components bioperl-module-names-cache))))
	   ((not retopt)
	     (delete nil (mapcar 
			  (lambda (x) (if (listp x) nil x)) 
			  (cdr (deep-assoc module-components bioperl-module-names-cache)))))
	   ( retopt
	     (delete nil (mapcar 
			  (lambda (x) (if (listp x) (car x) nil)) 
			  (cdr (deep-assoc module-components bioperl-module-names-cache))))))
	nil))))


;;
;; pod slurpers
;;

(defun bioperl-view-full-pod (module) 
  "Open the Bioperl POD for the MODULE for viewing in another buffer.
MODULE is in double-colon format."
  (unless bioperl-system-pod2text 
    (unless (bioperl-find-system-pod2text)
      (error "Can't find pod2text; try setting bioperl-system-pod2text manually")))
  (unless (bioperl-check-system-pod2text)
    (error "Unexpected command in bioperl-system-pod2text; aborting..."))
  (unless (and module (stringp module))
    (error "String required at arg MODULE"))
  (if (not module)
      nil
    (let (
	  (old-exec-path exec-path)
	  (pod-buf (generate-new-buffer "*BioPerl POD*"))
	  (pmfile (bioperl-path-from-perl module))
	  (args bioperl-pod2text-args)
	  )
      (unless pmfile
	(error "Module specified by MODULE not found in installation"))
      ;; safe path
      (setq exec-path bioperl-safe-PATH)
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

(defun bioperl-view-pod-section (module section)
  "Open the Bioperl POD for the module PMFILE for viewing in another buffer."
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

  (let (
	(pod-buf (generate-new-buffer "*BioPerl POD*"))
	(args '("-a"))
	(ret nil)
	(pmfile (bioperl-path-from-perl module))
	(old-exec-path exec-path)
	)
    (unless pmfile
      (error "Module specified by MODULE not found in installation"))
    ;; safe path
    (setq exec-path bioperl-safe-PATH)
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

(defun bioperl-slurp-methods-from-pod (module) 
  "Parse pod for individual methods for module MODULE.
MODULE is in double-colon format.

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
	(pmfile (bioperl-path-from-perl module))
	)
    (unless pmfile
      (error "Module specified by MODULE not found in installation"))
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
    (setq exec-path bioperl-safe-PATH)
    (with-temp-buffer
      (if (not (= 0
		(call-process bioperl-system-pod2text
				  nil t t pmfile "-a")))
	  (error "pos2text failed"))
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

(defun bioperl-add-module-names-to-cache (module-dir)
  "Add alists to `bioperl-module-names-cache'.
MODULE-DIR is in double colon format. Allows for lazy build of
the cache.  Returns t if we added anything, nil if not"
  (unless (and module-dir (stringp module-dir))
    (error "String required at arg MODULE-DIR"))
  (let (
	(pth (bioperl-path-from-perl module-dir 1))
	(module-components (split-string module-dir "::"))
	(module-string nil)
	(modules nil)
	(cache-pos nil)
	(keys nil)
	(this-key nil)
	(good-keys nil)
	(ret nil)
       )
    (if (not pth)
	;; no path returned for module-dir...
	nil
      (setq cache-pos (deep-assoc module-components bioperl-module-names-cache))
      (if (and cache-pos (cdr cache-pos))
	  nil ;; an alist already present at this location...
	;; otherwise, none or a stub; do real work
	;; find the key at which to add info...
	;; value return by assoc is really a pointer into the
	;; original alist.
	(if cache-pos
	    ;; easy
	    (progn
	      (setcdr cache-pos (bioperl-slurp-module-names module-dir))
	      (setq ret t))
	  ;; hard
	  (setq keys module-components)
	  (while (deep-assoc (append good-keys (list (car keys))) bioperl-module-names-cache)
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
	    (setq modules (bioperl-slurp-module-names module-string))
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
	))
  ret ))

(defun bioperl-slurp-module-names (module-dir)
  "Return list of basenames for .pm files contained in MODULE-DIR.
MODULE-DIR is in double-colon format."
  (unless (and module-dir (stringp module-dir))
    (error "String required at arg MODULE-DIR"))
  (let (
	(pth (bioperl-path-from-perl module-dir 1))
	(modules nil)
	(fnames nil)
       )
    ;; following (elt ... 0) checks if pth is dir or symlink
    ;; possible bug...
    ;; try including directory names too, as (list (cons name nil))
    ;; stubs for descending into those later...
    (if (and pth (elt (file-attributes pth) 0))
	(progn
	  (setq fnames (directory-files pth))
	  (while fnames 
	    (let ( (str (pop fnames)))
	      ;; files - strings
	      (if (string-match "\\([a-zA-Z0-9_]+\\)\.pm$" str)
		  (push (match-string 1 str) modules))
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
  "Look for something like a module declaration at point, and return it."
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

(defun bioperl-find-module-at-point ()
  "Look for something like a module declaration at point, and return a filepath corresponding to it."
  (interactive)
  (unless bioperl-module-path
    (error "bioperl-module-path not yet set; you can set it with bioperl-find-module-path"))
  (let (
	(found (thing-at-point-looking-at "Bio::[a-zA-Z_:]+"))
	(module nil)
	(pth nil)
	)
    (if (not found) 
	nil
      (setq module (apply 'buffer-substring (match-data)))
      (setq pth (bioperl-path-from-perl module)))
    pth))


(defun bioperl-path-from-perl (module &optional dir-first) 
  "Return a path to the module file represented by the perl string MODULE.
Returns nil if no path found. If DIR-FIRST is t, return a
directory over a .pm file if there is a choice. If DIR-FIRST is
not t or nil, return a directory only."
  (unless bioperl-module-path
    (error "bioperl-module-path not yet set; you can set it with bioperl-find-module-path"))
  (unless (stringp module)
    (error "string arg required at MODULE"))
  (let (
	(module-components '())
	(pth nil)
	(dir (if (not (boundp 'dir-first)) nil dir-first))
	)
    (setq module-components (split-string module "::"))
    ;; unixize...
    (setq pth (subst-char-in-string ?\\ ?/ bioperl-module-path))
    
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

(defun bioperl-split-name (module &optional dir-first)
  "Examine MODULE and return a list splitting the argument into an existing namespace and module name.
MODULE is in double-colon format. This checks existence as well,
and returns nil if no split corresponds to an existing file. The
algorithm uses `bioperl-path-from-perl' to do its tests.  Default
behavior is to return (namespace module) if there is a choice.
If DIR-FIRST is t, return (namespace nil) over (namespace module)
if there is a choice. If DIR-FIRST is not t or nil, return only
\(namespace nil) or nil.

Finally, if the namespace portion of MODULE exists, but the module
specified by MODULE does not, (namespace ) is returned."
  (unless (or (not module) (stringp module))
    (error "String arg required at MODULE"))
  (if (not module)
      (list nil nil)
    (if (not (string-match "^Bio" module))
	nil
      ( let ( (nmspc) (mod) (pmfile) )
	(if (not (string-match "::\\([a-zA-Z0-9_]+\\)$" module))
	    (setq nmspc module)
	  (setq mod (match-string 1 module))
	  (setq nmspc (substring module 0 (- (match-beginning 1) 2))))
	(cond
	 ( (not (booleanp dir-first))
	   (if (bioperl-path-from-perl module dir-first)
	       (list module nil)
	     (list (concat "*" module) nil)) )
	 ( t 
	   (setq pmfile (bioperl-path-from-perl module dir-first))
	   (if pmfile
	       (if (string-match "\.pm$" pmfile)
		   (list nmspc mod)
		 (list module nil))
	     (if dir-first
		 (progn (setq nmspc (concat nmspc "::" mod))
			(setq mod nil)))
	     (if (bioperl-path-from-perl nmspc 1)
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
or nil. Returns a list: (namespace module) if GET-METHOD is nil,
\(namespace module method) if GET-METHOD is t. DIR-FIRST is
passed along to `bioperl-split-name'; controls what is returned
when a namespace name is also a module name (e.g., Bio::SeqIO).
If NO-RETRY is nil, the reader works hard to return a valid entity;
if t, the reader barfs out whatever was finally entered."
  (let ( (parsed (bioperl-split-name initial-input dir-first)) 
	 (nmspc) (mod) (mth) 
	 (done nil))
    (if (not parsed)
	nil
      (setq nmspc (elt parsed 0))
      (setq mod (elt parsed 1)))
    (while (not done)
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
      (if (or (not nmspc)
		  (and mod (not (string-match "^\*" mod))))
	  (setq done t)
	(setq mod (completing-read 
		   (concat prompt-prefix nmspc " Module: ")
		   (bioperl-module-names nmspc) nil (not no-retry)
		   (if mod (replace-regexp-in-string "^\*" "" mod) nil)))
	;; allow a backup into namespace completion
	(if (or no-retry (not (string-equal mod "")))
	    (setq done t)
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
	  (setq initial-input nmspc)))
      (unless (or (not done) (not (and nmspc mod)) (not get-method))
	(setq mth (completing-read
		   (concat prompt-prefix "Method in " nmspc "::" mod ": ")
		   (bioperl-method-names (concat nmspc "::" mod)) nil (not no-retry)))
	(if (or no-retry (not (string-equal mth "")))
	    (setq done t)
	    ;; allow a backup into module completion
	  (setq done nil)
 	  (let ( (splt (bioperl-split-name (concat nmspc "::" mod) nil)) )
	    (setq nmspc (elt splt 0))
	    ;; kludge : "pretend" mod is not found using the "*"
	    (setq mod (concat "*" (elt splt 1))))) ))
    (if get-method
	(list nmspc mod mth)
      (list nmspc mod)) ))

(defun bioperl-namespace-completion-function (str pred flag)
  "A custom completion function for bioperl-mode.
Allows the lazy build of the `bioperl-module-names-cache'."
  (if (not pred) 
      (setq pred 
	    (lambda (x) (setq x (if (listp x) (car x) x) ) (if (string-match "[a-zA-Z0-9_:]+" x) t nil))
	    ))
  (let (
	( collection (if (string-equal str "") '("Bio") (bioperl-make-collection str t)) )
	( str-trunc (if (string-match ":" str)
			(progn (string-match  "^\\(\\(?:[a-zA-Z0-9_]+::\\)+\\)\\(?::*\\|[a-zA-Z0-9_]*\\)$" str) (match-string 1 str))
		      str) )

	)
    ;; offer the right collection:
    ;; if collection was set, the str was complete and valid
    ;; if not, back up to the last :: in str (see str-trunc in above
    ;; let) and try again
    (if (not collection)
	(setq collection (bioperl-make-collection str-trunc t)))
    (if (not collection) 
	nil
      (setq collection (sort collection 'string-lessp))
      (cond
       ((not (booleanp flag)) ;; 'lambda' or test-completion option
	(test-completion str collection pred)
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
	   ( modules (split-string module-dir "::") )
	   ( complet (let* ( (l modules)
			     (m (list (pop l))) )
		       (while l
			 (push (concat (car m) "::" (pop l)) m) )
		       m) )
	   ( dirs nil )
	   )
      (setq dirs (bioperl-module-names module-dir retopt))
      (if dirs
	  (append complet (mapcar (lambda (x) (concat module-dir "::" x)) dirs))
	nil)
      )))

;;
;; taint checkers
;;

(defun bioperl-check-system-pod2text ()
  "See if `bioperl-system-pod2text' is naughty."
  (if (and bioperl-system-pod2text (string-match "pod2text\\(\\|\\.bat|\\.exe\\)$" bioperl-system-pod2text))
      t
    nil))

;;
;; utilities (out of bioperl- namespace)
;;

(defun deep-assoc (keys alist)
  "Return the association of a set of keys in an alist tree."
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
