################################################################################
# CHANGE LOG (last 20 changes)
# 03.03.2019: Compacted and tweaked widgets under tcltk.
# 17.02.2019: Fixed Error in if (svalue(savegui_chk)) { : argument is of length zero (tcltk)
# 06.08.2017: Added audit trail.
# 13.07.2017: Fixed issue with button handlers.
# 13.07.2017: Fixed narrow dropdown with hidden argument ellipsize = "none".
# 07.07.2017: Replaced 'droplist' with 'gcombobox'.
# 07.07.2017: Removed argument 'border' for 'gbutton'.
# 27.06.2016: Added expand=TRUE to save as field.
# 09.01.2016: Added more attributes to result.
# 28.08.2015: Added importFrom
# 11.10.2014: Added 'focus', added 'parent' parameter.
# 28.06.2014: Added help button and moved save gui checkbox.
# 06.05.2014: Implemented 'checkDataset'.
# 27.11.2013: First version.


#' @title Add Missing Markers
#'
#' @description
#' GUI wrapper for the \code{\link{addMarker}} function.
#'
#' @details
#' Simplifies the use of the \code{\link{addMarker}} function by providing a graphical
#' user interface to it.
#'
#' @param env environment in which to search for data frames and save result.
#' @param savegui logical indicating if GUI settings should be saved in the environment.
#' @param debug logical indicating printing debug information.
#' @param parent widget to get focus when finished.
#'
#' @return TRUE
#'
#' @export
#'
#' @importFrom utils head help
#'
#' @seealso \code{\link{addMarker}}

addMarker_gui <- function(env = parent.frame(), savegui = NULL, debug = FALSE, parent = NULL) {

  # Global variables.
  .gData <- data.frame(No.Data = NA)
  .gDataName <- NULL
  .gKit <- 1

  if (debug) {
    print(paste("IN:", match.call()[[1]]))
    print(head(.gData))
  }

  # Main window.
  w <- gwindow(title = "Add missing markers to dataset", visible = FALSE)

  # Runs when window is closed.
  addHandlerUnrealize(w, handler = function(h, ...) {

    # Save GUI state.
    .saveSettings()

    # Focus on parent window.
    if (!is.null(parent)) {
      focus(parent)
    }

    # Check which toolkit we are using.
    if (gtoolkit() == "tcltk") {
      if (as.numeric(gsub("[^0-9]", "", packageVersion("gWidgets2tcltk"))) <= 106) {
        # Version <= 1.0.6 have the wrong implementation:
        # See: https://stackoverflow.com/questions/54285836/how-to-retrieve-checkbox-state-in-gwidgets2tcltk-works-in-gwidgets2rgtk2
        message("tcltk version <= 1.0.6, returned TRUE!")
        return(TRUE) # Destroys window under tcltk, but not RGtk2.
      } else {
        # Version > 1.0.6 will be fixed:
        # https://github.com/jverzani/gWidgets2tcltk/commit/9388900afc57454b6521b00a187ca4a16829df53
        message("tcltk version >1.0.6, returned FALSE!")
        return(FALSE) # Destroys window under tcltk, but not RGtk2.
      }
    } else {
      message("RGtk2, returned FALSE!")
      return(FALSE) # Destroys window under RGtk2, but not with tcltk.
    }
  })

  # Vertical main group.
  gv <- ggroup(
    horizontal = FALSE,
    spacing = 5,
    use.scrollwindow = FALSE,
    container = w,
    expand = TRUE
  )

  # Help button group.
  gh <- ggroup(container = gv, expand = FALSE, fill = "both")

  savegui_chk <- gcheckbox(text = "Save GUI settings", checked = FALSE, container = gh)

  addSpring(gh)

  help_btn <- gbutton(text = "Help", container = gh)

  addHandlerChanged(help_btn, handler = function(h, ...) {

    # Open help page for function.
    print(help("addMarker_gui", help_type = "html"))
  })

  # DATASET ###################################################################

  f0 <- gframe(
    text = "Dataset and kit",
    horizontal = FALSE,
    spacing = 2,
    container = gv
  )

  f0g1 <- glayout(container = f0, spacing = 1)

  f0g1[1, 1] <- glabel(text = "Select dataset:", container = f0g1)

  f0g1[1, 2] <- dataset_drp <- gcombobox(
    items = c(
      "<Select dataset>",
      listObjects(
        env = env,
        obj.class = "data.frame"
      )
    ),
    selected = 1,
    editable = FALSE,
    container = f0g1,
    ellipsize = "none"
  )

  f0g1[1, 3] <- dataset_samples_lbl <- glabel(
    text = " 0 samples",
    container = f0g1
  )

  addHandlerChanged(dataset_drp, handler = function(h, ...) {
    val_obj <- svalue(dataset_drp)

    # Check if suitable.
    requiredCol <- c("Sample.Name", "Marker")
    ok <- checkDataset(
      name = val_obj, reqcol = requiredCol,
      env = env, parent = w, debug = debug
    )

    if (ok) {
      # Load or change components.

      # Get data.
      .gData <<- get(val_obj, envir = env)

      # Load or change components.
      .gDataName <<- val_obj
      samples <- length(unique(.gData$Sample.Name))
      svalue(dataset_samples_lbl) <- paste(" ", samples, "samples")
      .gKit <<- detectKit(.gData, index = TRUE)
      svalue(kit_drp, index = TRUE) <- .gKit
      svalue(save_edt) <- paste(.gDataName, "_marker", sep = "")

      if (debug) {
        print("Detected kit index")
        print(.gKit)
      }
    } else {

      # Reset components.
      .gData <<- data.frame(No.Data = NA)
      .gDataName <<- NULL
      svalue(dataset_samples_lbl) <- " 0 samples"
      svalue(save_edt) <- ""
    }
  })

  # KIT -----------------------------------------------------------------------

  f0g1[2, 1] <- glabel(text = "Kit:", container = f0g1)

  kit_drp <- gcombobox(
    items = getKit(),
    selected = 1,
    editable = FALSE,
    container = f0g1,
    ellipsize = "none"
  )

  f0g1[2, 2] <- kit_drp

  # FRAME 1 ###################################################################

  # OPTIONS -----------------------------------------------------------------------

  f1 <- gframe(
    text = "Options",
    horizontal = FALSE,
    spacing = 2,
    container = gv
  )

  f1_ignore_chk <- gcheckbox(
    text = "Ignore case (marker name)",
    checked = FALSE, container = f1
  )

  # SAVE ######################################################################

  save_frame <- gframe(text = "Save as", container = gv)

  glabel(text = "Name for result:", container = save_frame)

  save_edt <- gedit(expand = TRUE, fill = TRUE, container = save_frame)

  # BUTTON ####################################################################

  if (debug) {
    print("BUTTON")
  }

  add_btn <- gbutton(text = "Add marker", container = gv)

  addHandlerClicked(add_btn, handler = function(h, ...) {

    # Get values.
    val_kit <- svalue(kit_drp)
    val_data <- .gData
    val_data_name <- .gDataName
    val_ignore <- svalue(f1_ignore_chk)
    val_name <- svalue(save_edt)

    if (debug) {
      print(".gData")
      print(names(.gData))
      print("val_kit")
      print(val_kit)
    }

    # Change button.
    blockHandlers(add_btn)
    svalue(add_btn) <- "Processing..."
    unblockHandlers(add_btn)
    enabled(add_btn) <- FALSE

    datanew <- addMarker(
      data = val_data,
      marker = getKit(val_kit, what = "Marker"),
      ignore.case = val_ignore, debug = debug
    )

    # Add attributes to result.
    attr(datanew, which = "kit") <- val_kit

    # Create key-value pairs to log.
    keys <- list("data", "kit", "ignore.case")

    values <- list(val_data_name, val_kit, val_ignore)

    # Update audit trail.
    datanew <- auditTrail(
      obj = datanew, key = keys, value = values,
      label = "addMarker_gui", arguments = FALSE,
      package = "strvalidator"
    )

    # Save data.
    saveObject(name = val_name, object = datanew, parent = w, env = env)

    # Close GUI.
    .saveSettings()
    dispose(w)
  })

  # INTERNAL FUNCTIONS ########################################################

  .loadSavedSettings <- function() {

    # First check status of save flag.
    if (!is.null(savegui)) {
      svalue(savegui_chk) <- savegui
      enabled(savegui_chk) <- FALSE
      if (debug) {
        print("Save GUI status set!")
      }
    } else {
      # Load save flag.
      if (exists(".strvalidator_addMarker_gui_savegui", envir = env, inherits = FALSE)) {
        svalue(savegui_chk) <- get(".strvalidator_addMarker_gui_savegui", envir = env)
      }
      if (debug) {
        print("Save GUI status loaded!")
      }
    }
    if (debug) {
      print(svalue(savegui_chk))
    }

    # Then load settings if true.
    if (svalue(savegui_chk)) {
      if (exists(".strvalidator_addMarker_gui_ignore", envir = env, inherits = FALSE)) {
        svalue(f1_ignore_chk) <- get(".strvalidator_addMarker_gui_ignore", envir = env)
      }

      if (debug) {
        print("Saved settings loaded!")
      }
    }
  }

  .saveSettings <- function() {

    # Then save settings if true.
    if (svalue(savegui_chk)) {
      assign(x = ".strvalidator_addMarker_gui_savegui", value = svalue(savegui_chk), envir = env)
      assign(x = ".strvalidator_addMarker_gui_ignore", value = svalue(f1_ignore_chk), envir = env)
    } else { # or remove all saved values if false.

      if (exists(".strvalidator_addMarker_gui_savegui", envir = env, inherits = FALSE)) {
        remove(".strvalidator_addMarker_gui_savegui", envir = env)
      }
      if (exists(".strvalidator_addMarker_gui_ignore", envir = env, inherits = FALSE)) {
        remove(".strvalidator_addMarker_gui_ignore", envir = env)
      }

      if (debug) {
        print("Settings cleared!")
      }
    }

    if (debug) {
      print("Settings saved!")
    }
  }

  # END GUI ###################################################################

  # Load GUI settings.
  .loadSavedSettings()

  # Show GUI.
  visible(w) <- TRUE
  focus(w)
} # End of GUI
