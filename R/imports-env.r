#' Return imports environment for a package
#'
#' Contains objects imported from other packages. Is the parent of the
#' package namespace environment, and is a child of <namespace:base>,
#' which is a child of R_GlobalEnv.
#' @keywords internal
#' @param pkg package description, can be path or package name.  See
#'   \code{\link{as.package}} for more information.
#' @seealso \code{\link{ns_env}} for the namespace environment that
#'   all the objects (exported and not exported).
#' @seealso \code{\link{pkg_env}} for the attached environment that contains
#'   the exported objects.
#' @export
imports_env <- function(pkg = ".") {
  pkg <- as.package(pkg)

  if (!is_loaded(pkg)) {
    stop("Namespace environment must be created before accessing imports environment.")
  }

  env <- parent.env(ns_env(pkg))

  if (attr(env, 'name') != imports_env_name(pkg)) {
    stop("Imports environment does not have attribute 'name' with value ",
      imports_env_name(pkg),
      ". This probably means that the namespace environment was not created correctly.")
  }

  env
}


# Generate name of package imports environment
# Contains exported objects
imports_env_name <- function(pkg = ".") {
  pkg <- as.package(pkg)
  paste("imports:", pkg$package, sep = "")
}


#' Load all of the imports for a package
#'
#' The imported objects are copied to the imports environment, and are not
#' visible from R_GlobalEnv. This will automatically load (but not attach)
#' the dependency packages.
#'
#' @keywords internal
load_imports <- function(pkg = ".") {
  pkg <- as.package(pkg)

  # Get data frame of dependency names and versions
  deps <- parse_deps(pkg$imports)
  if (is.null(deps) || nrow(deps) == 0) return(invisible())

  # If we've already loaded imports, don't load again (until load_all
  # is run with reset=TRUE). This is to avoid warnings when running
  # process_imports()
  if (length(ls(imports_env(pkg))) > 0) return(invisible(deps))

  mapply(check_dep_version, deps$name, deps$version, deps$compare)

  process_imports(pkg)

  invisible(deps)
}

# Load imported objects
# The code in this function is taken and adapted from base::loadNamespace
# Setup variables were added and the for loops put in a tryCatch block
# https://github.com/wch/r-source/blob/tags/R-3-3-0/src/library/base/R/namespace.R#L397-L427

# This wraps the inner for loop iterations in a tryCatch
wrap_inner_loop <- function(x) {
  inner <- x[[4]]
  x[[4]] <- call("tryCatch", error = quote(warning), inner)
  x
}

onload_assign("process_imports", {
  make_function(alist(pkg = "."),
    bquote({
      package <- pkg$name
      vI <- ("tools" %:::% ".split_description")(("tools" %:::% ".read_description")(file.path(pkg$path, "DESCRIPTION")))$Imports
      nsInfo <- parse_ns_file(pkg)
      ns <- ns_env(pkg)
      lib.loc <- NULL
      .(for1)
      .(for2)
      .(for3)
    }, list(
        for1 = wrap_inner_loop(
          extract_lang(body(loadNamespace), comp_lang, y = quote(for(i in nsInfo$imports) NULL), idx = 1:3)),

        for2 = wrap_inner_loop(extract_lang(body(loadNamespace),
          comp_lang, y = quote(for(imp in nsInfo$importClasses) NULL), idx = 1:3)),

        for3 = wrap_inner_loop(extract_lang(body(loadNamespace),
          comp_lang, y = quote(for(imp in nsInfo$importMethods) NULL), idx = 1:3))
        )), asNamespace("pkgload"))
})
