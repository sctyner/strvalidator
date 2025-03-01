################################################################################
# CHANGE LOG (last 20 changes)
# 20.02.2019: Fixed "error in if(ok) argument not logical" using tcltk.
# 29.04.2016: Fixed object not saved if an object existed and the new object is renamed.
# 18.07.2014: Added syntactically valid name check.
# 18.07.2014: Added 'remove' and 'suggested' parameter.
# 20.01.2014: Added 'debug' parameter.
# 17.07.2013: First version.

#' @title Save Object
#'
#' @description
#' Save an object in the specified environment.
#'
#' @details Saves an object with the given name in the specified environment
#' if it does not exist. If the object exist a message box ask if the object
#' should be overwritten. The function can also be used to re-name if 'name'
#' is not provided (NULL). The 'suggest' provides a suggested name for the
#' object to re-name.
#'
#' @param name character giving the name of the object to save.
#' If NULL a dialogue asks for a name.
#' @param object object to save.
#' @param parent object specifying the parent GUI object to center the message box.
#' @param suggest character string for a suggested name for the object to save/re-name.
#' @param env environment in which to save and search for existing objects.
#' @param remove character string for a named object to remove (e.g. the original object if re-naming).
#' @param debug logical indicating printing debug information.
#'
#' @keywords internal
#'
#' @return logical TRUE if object was saved FALSE if not.
#'

saveObject <- function(name = NULL, object, parent = NULL, suggest = "",
                       env = parent.frame(), remove = NULL, debug = FALSE) {
  if (debug) {
    print(paste("IN:", match.call()[[1]]))
    print("name:")
    print(name)
    print("names(object)")
    print(names(object))
  }

  # Initiate flag.
  ok <- TRUE

  # Check if name is provided.
  if (is.null(name)) {

    # Show dialogue.
    name <- ginput(
      msg = "Enter name", text = suggest,
      title = "Input", icon = "info", parent = parent
    )

    if (is.na(name)) {
      if (debug) {
        print("User pressed cancel!")
      }

      # Return FALSE.
      return(ok)
    }

    if (debug) {
      print(paste("Input name:", name))
    }
  }

  # Check that a name has been provided for the new data object.
  if (nchar(name) > 0) {

    # Make syntactically valid name.
    orgName <- name
    name <- make.names(name)

    if (name != orgName) {

      # Create message.
      txt <- paste(
        orgName, "is not a syntactically valid name!\n\n",
        "The object will be saved as:", name
      )

      # Show message.
      gmessage(
        msg = txt, title = "Invalid name",
        icon = "warning",
        parent = parent
      )
    }

    # Check for existing object and ask for user input.
    if (exists(name, envir = env, inherits = FALSE)) {
      if (debug) {
        print(paste("Object", name, "exists!"))
      }

      msg <- paste("An object named '", name, "' already exist.\n\n",
        "Do you want to overwrite?",
        sep = ""
      )

      ok <- gconfirm(
        msg = msg, title = "Warning!",
        icon = "warning", parent = parent
      )
    }

    if (ok) {

      # Save data.
      assign(name, object, envir = env)

      if (debug) {
        print(paste("Object", name, "saved!"))
      }
    } else {

      # Ask for new name.
      name <- ginput(
        msg = "New name", text = name, title = "Input",
        icon = "info", parent = parent
      )

      # Exit if cancel.
      if (is.na(name)) {
        if (debug) {
          print("User pressed cancel!")
        }

        # Return FALSE.
        return(ok)
      } else {

        # Save data.
        assign(name, object, envir = env)

        if (debug) {
          print(paste("New name:", name))
        }
      }
    }

    # Remove only if different from final name.
    if (!is.null(remove) && remove != name) {

      # Delete object.
      remove(list = remove, envir = env)

      if (debug) {
        print(paste("Object", remove, "deleted!"))
      }
    }
  } else {
    gmessage("A name must be provided.",
      title = "Error", icon = "error", parent = parent
    )

    ok <- FALSE # Set flag.
  }

  return(ok)
}
