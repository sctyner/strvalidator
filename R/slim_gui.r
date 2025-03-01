################################################################################
# CHANGE LOG (last 20 changes)
# 02.03.2019: Fixed expansion of widgets under tcltk.
# 17.02.2019: Fixed Error in if (svalue(savegui_chk)) { : argument is of length zero (tcltk)
# 07.08.2017: Added audit trail.
# 13.07.2017: Fixed issue with button handlers.
# 13.07.2017: Fixed narrow dropdown with hidden argument ellipsize = "none".
# 07.07.2017: Replaced 'droplist' with 'gcombobox'.
# 07.07.2017: Removed argument 'border' for 'gbutton'.
# 07.07.2017: Replaced gWidgets:: with gWidgets2::
# 24.06.2016: 'Save as' textbox expandable.
# 06.01.2016: Added attributes to result.
# 29.08.2015: Added importFrom.
# 07.10.2014: Added 'focus', added 'parent' parameter.
# 28.06.2014: Added help button and moved save gui checkbox.
# 08.05.2014: Implemented 'checkDataset'.
# 02.12.2013: Fixed 'Option' frame not visible.
# 20.11.2013: Specified package for function 'gtable' -> 'gWidgets::gtable'
# 06.08.2013: Added rows and columns to info.
# 18.07.2013: Check before overwrite object.
# 16.07.2013: Added save GUI settings.
# 11.06.2013: Added 'inherits=FALSE' to 'exists'.

#' @title Slim Data Frames
#'
#' @description
#' GUI wrapper for the \code{\link{slim}} function.
#'
#' @details
#' Simplifies the use of the \code{\link{slim}} function by providing a graphical
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
#' @importFrom utils help
#'
#' @seealso \code{\link{slim}}

slim_gui <- function(env = parent.frame(), savegui = NULL,
                     debug = FALSE, parent = NULL) {

  # Global variables.
  .gData <- data.frame(No.Data = NA)
  .gDataName <- NULL

  if (debug) {
    print(paste("IN:", match.call()[[1]]))
  }

  # Main window.
  w <- gwindow(title = "Slim dataset", visible = FALSE)

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
    print(help("slim_gui", help_type = "html"))
  })


  # Vertical sub group.
  g0 <- ggroup(
    horizontal = FALSE,
    spacing = 2,
    use.scrollwindow = FALSE,
    container = gv,
    expand = FALSE,
    fill = TRUE
  )

  # Horizontal sub group.
  g1 <- ggroup(
    horizontal = TRUE,
    spacing = 2,
    use.scrollwindow = FALSE,
    container = gv,
    expand = TRUE,
    fill = TRUE
  )

  # Vertical sub group.
  g2 <- ggroup(
    horizontal = FALSE,
    spacing = 2,
    use.scrollwindow = FALSE,
    container = gv,
    expand = FALSE,
    fill = TRUE
  )


  # DATASET ###################################################################

  f0 <- gframe(
    text = "Datasets",
    horizontal = FALSE,
    spacing = 2,
    container = g0
  )

  f0g0 <- glayout(container = f0, spacing = 1)

  f0g0[1, 1] <- glabel(text = "Select dataset:", container = f0g0)

  f0g0[1, 2] <- dataset_drp <- gcombobox(
    items = c(
      "<Select dataset>",
      listObjects(
        env = env,
        obj.class = "data.frame"
      )
    ),
    selected = 1,
    editable = FALSE,
    container = f0g0,
    ellipsize = "none"
  )

  f0g0[1, 3] <- f0_samples_lbl <- glabel(text = " 0 samples,", container = f0g0)
  f0g0[1, 4] <- f0_columns_lbl <- glabel(text = " 0 columns,", container = f0g0)
  f0g0[1, 5] <- f0_rows_lbl <- glabel(text = " 0 rows", container = f0g0)


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
      .gData <<- get(val_obj, envir = env)
      .gDataName <<- val_obj

      .refresh_fix_tbl()
      .refresh_stack_tbl()

      samples <- length(unique(.gData$Sample.Name))
      # Info.
      if ("Sample.Name" %in% names(.gData)) {
        samples <- length(unique(.gData$Sample.Name))
        svalue(f0_samples_lbl) <- paste(" ", samples, "samples,")
      } else {
        svalue(f0_samples_lbl) <- paste(" ", "<NA>", "samples,")
      }
      svalue(f0_columns_lbl) <- paste(" ", ncol(.gData), "columns,")
      svalue(f0_rows_lbl) <- paste(" ", nrow(.gData), "rows")
      # Result name.
      svalue(save_edt) <- paste(val_obj, "_slim", sep = "")

      # Guess column names to keep fixed.
      svalue(fix_edt) <- colNames(data = .gData, slim = TRUE, numbered = TRUE, concatenate = "|")

      # Guess column names to stack.
      svalue(stack_edt) <- colNames(data = .gData, slim = FALSE, numbered = TRUE, concatenate = "|")

      # Reset button.
      svalue(slim_btn) <- "Slim dataset"
      enabled(slim_btn) <- TRUE
    } else {

      # Reset components.
      .gData <<- data.frame(No.Data = NA)
      .gDataName <<- NULL
      svalue(fix_edt) <- ""
      svalue(stack_edt) <- ""
      .refresh_fix_tbl()
      .refresh_stack_tbl()
      svalue(f0_samples_lbl) <- paste(" ", "<NA>", "samples,")
      svalue(f0_columns_lbl) <- paste(" ", "<NA>", "columns,")
      svalue(f0_rows_lbl) <- paste(" ", "<NA>", "rows")
      svalue(save_edt) <- ""
    }
  })

  # SAMPLES ###################################################################

  if (debug) {
    print("SAMPLES")
    print(unique(.gData$Sample.Name))
  }

  fix_f <- gframe("Fix",
    horizontal = FALSE, container = g1,
    expand = TRUE, fill = TRUE
  )

  fix_lbl <- glabel(
    text = "Columns to keep fixed (separate by pipe |):",
    container = fix_f,
    anchor = c(-1, 0)
  )

  fix_edt <- gedit(
    initial.msg = "Doubleklick or drag column names to list",
    width = 40,
    container = fix_f
  )

  fix_tbl <- gWidgets2::gtable(
    items = names(.gData),
    container = fix_f,
    expand = TRUE
  )

  # Set initial size (only height is important here).
  size(fix_tbl) <- c(100, 200)

  addDropTarget(fix_edt, handler = function(h, ...) {
    if (debug) {
      print("SAMPLES:DROPTARGET")
    }

    # Get values.
    drp_val <- h$dropdata
    fix_val <- svalue(h$obj)

    # Add new value to selected.
    new <- ifelse(nchar(fix_val) > 0,
      paste(fix_val, drp_val, sep = "|"),
      drp_val
    )

    # Update text box.
    svalue(h$obj) <- new

    # Update sample name table.
    tmp_tbl <- fix_tbl[, ] # Get all values.
    print(tmp_tbl)
    tmp_tbl <- tmp_tbl[tmp_tbl != drp_val] # Remove value added to selected.
    fix_tbl[, ] <- tmp_tbl # Update table.
  })

  # COLUMNS ###################################################################

  if (debug) {
    print("STACK")
  }

  stack_f <- gframe("Stack",
    horizontal = FALSE, container = g1,
    expand = TRUE, fill = TRUE
  )

  stack_lbl <- glabel(
    text = "Columns to stack (separate by pipe |):",
    container = stack_f,
    anchor = c(-1, 0)
  )

  stack_edt <- gedit(
    initial.msg = "Doubleklick or drag column names to list",
    width = 40,
    container = stack_f
  )

  stack_tbl <- gWidgets2::gtable(
    items = names(.gData),
    container = stack_f,
    expand = TRUE
  )

  addDropTarget(stack_edt, handler = function(h, ...) {
    # Get values.
    drp_val <- h$dropdata
    stack_val <- svalue(h$obj)

    # Add new value to selected.
    new <- ifelse(nchar(stack_val) > 0,
      paste(stack_val, drp_val, sep = "|"),
      drp_val
    )

    # Update text box.
    svalue(h$obj) <- new

    # Update column name table.
    tmp_tbl <- stack_tbl[, ] # Get all values.
    print(tmp_tbl)
    tmp_tbl <- tmp_tbl[tmp_tbl != drp_val] # Remove value added to selected.
    stack_tbl[, ] <- tmp_tbl # Update table.
  })

  # FRAME 1 ###################################################################

  if (debug) {
    print("OPTIONS")
  }

  f1 <- gframe("Options", horizontal = FALSE, container = g0)

  f1_keep_chk <- gcheckbox(
    text = "Keep rows in fixed columns even if no data in stacked columns",
    checked = TRUE,
    container = f1
  )

  glabel(
    text = paste("(i.e. keep one row per marker for each sample even if no peak)"),
    container = f1, anchor = c(-1, 0)
  )

  glabel(
    text = paste(
      "\nTip:",
      "Manually edit the columns to fix and stack.\n",
      "e.g. 'Allele' will stack 'Allele.1', 'Allele.2'..."
    ),
    container = f1,
    anchor = c(-1, 0)
  )

  # SAVE ######################################################################

  save_frame <- gframe(text = "Save as", container = g2)

  glabel(text = "Name for result:", container = save_frame)

  save_edt <- gedit(expand = TRUE, fill = TRUE, container = save_frame)

  # BUTTON ####################################################################

  slim_btn <- gbutton(text = "Slim dataset", container = g2)

  addHandlerClicked(slim_btn, handler = function(h, ...) {

    # Get new dataset name.
    val_name <- svalue(save_edt)
    val_data <- .gData
    val_data_name <- .gDataName

    if (nchar(val_name) > 0) {

      # Get values.
      fix_val <- svalue(fix_edt)
      stack_val <- svalue(stack_edt)
      keep_val <- svalue(f1_keep_chk)

      # Slim require a vector of strings.
      fix_val <- unlist(strsplit(fix_val, "|", fixed = TRUE))
      stack_val <- unlist(strsplit(stack_val, "|", fixed = TRUE))

      if (debug) {
        print("val_data")
        print(names(val_data))
        print("fix_val")
        print(fix_val)
        print("stack_val")
        print(stack_val)
        print("keep_val")
        print(keep_val)
      }

      # Change button.
      blockHandlers(slim_btn)
      svalue(slim_btn) <- "Processing..."
      unblockHandlers(slim_btn)
      enabled(slim_btn) <- FALSE

      datanew <- slim(
        data = val_data, fix = fix_val, stack = stack_val,
        keep.na = keep_val, debug = debug
      )

      # Create key-value pairs to log.
      keys <- list("data", "fix", "stack", "keep.na")

      values <- list(val_data_name, fix_val, stack_val, keep_val)

      # Update audit trail.
      datanew <- auditTrail(
        obj = datanew, key = keys, value = values,
        label = "slim_gui", arguments = FALSE,
        package = "strvalidator"
      )

      # Save data.
      saveObject(name = val_name, object = datanew, parent = w, env = env)

      if (debug) {
        print(paste("EXIT:", match.call()[[1]]))
      }

      # Close GUI.
      .saveSettings()
      dispose(w)
    } else {
      gmessage("A file name must be provided!",
        title = "Error",
        icon = "error",
        parent = w
      )
    }
  })

  # INTERNAL FUNCTIONS ########################################################

  .refresh_fix_tbl <- function() {
    if (debug) {
      print(paste("IN:", match.call()[[1]]))
    }

    # Refresh widget by removing it and...
    delete(fix_f, fix_tbl)

    # ...creating a new table.
    fix_tbl <<- gWidgets2::gtable(
      items = names(.gData),
      container = fix_f,
      expand = TRUE
    )

    addDropSource(fix_tbl, handler = function(h, ...) svalue(h$obj))

    addHandlerDoubleclick(fix_tbl, handler = function(h, ...) {

      # Get values.
      tbl_val <- svalue(h$obj)
      fix_val <- svalue(fix_edt)

      # Add new value to selected.
      new <- ifelse(nchar(fix_val) > 0,
        paste(fix_val, tbl_val, sep = "|"),
        tbl_val
      )

      # Update text box.
      svalue(fix_edt) <- new

      # Update sample name table.
      tmp_tbl <- fix_tbl[, ] # Get all values.
      tmp_tbl <- tmp_tbl[tmp_tbl != tbl_val] # Remove value added to selected.
      fix_tbl[, ] <- tmp_tbl # Update table.
    })
  }

  .refresh_stack_tbl <- function() {
    if (debug) {
      print(paste("IN:", match.call()[[1]]))
    }

    # Refresh widget by removing it and...
    delete(stack_f, stack_tbl)

    # ...creating a new table.
    stack_tbl <<- gWidgets2::gtable(
      items = names(.gData),
      container = stack_f,
      expand = TRUE
    )

    addDropSource(stack_tbl, handler = function(h, ...) svalue(h$obj))

    addHandlerDoubleclick(stack_tbl, handler = function(h, ...) {

      # Get values.
      tbl_val <- svalue(h$obj)
      stack_val <- svalue(stack_edt)

      # Add new value to selected.
      new <- ifelse(nchar(stack_val) > 0,
        paste(stack_val, tbl_val, sep = "|"),
        tbl_val
      )

      # Update text box.
      svalue(stack_edt) <- new

      # Update column name table.
      tmp_tbl <- stack_tbl[, ] # Get all values.
      tmp_tbl <- tmp_tbl[tmp_tbl != tbl_val] # Remove value added to selected.
      stack_tbl[, ] <- tmp_tbl # Update table.
    })
  }

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
      if (exists(".strvalidator_slim_gui_savegui", envir = env, inherits = FALSE)) {
        svalue(savegui_chk) <- get(".strvalidator_slim_gui_savegui", envir = env)
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
      if (exists(".strvalidator_slim_gui_title", envir = env, inherits = FALSE)) {
        svalue(f1_keep_chk) <- get(".strvalidator_slim_gui_title", envir = env)
      }

      if (debug) {
        print("Saved settings loaded!")
      }
    }
  }

  .saveSettings <- function() {

    # Then save settings if true.
    if (svalue(savegui_chk)) {
      assign(x = ".strvalidator_slim_gui_savegui", value = svalue(savegui_chk), envir = env)
      assign(x = ".strvalidator_slim_gui_title", value = svalue(f1_keep_chk), envir = env)
    } else { # or remove all saved values if false.

      if (exists(".strvalidator_slim_gui_savegui", envir = env, inherits = FALSE)) {
        remove(".strvalidator_slim_gui_savegui", envir = env)
      }
      if (exists(".strvalidator_slim_gui_title", envir = env, inherits = FALSE)) {
        remove(".strvalidator_slim_gui_title", envir = env)
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
