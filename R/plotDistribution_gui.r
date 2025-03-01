################################################################################
# CHANGE LOG (last 20 changes)
# 24.02.2019: Compacted and tweaked gui for tcltk.
# 17.02.2019: Fixed Error in if (svalue(savegui_chk)) { : argument is of length zero (tcltk)
# 20.07.2018: Fixed blank drop-down menues after selecting a dataset.
# 20.07.2017: Removed unused argument 'spacing' from 'gexpandgroup'.
# 13.07.2017: Fixed issue with button handlers.
# 13.07.2017: Fixed expanded 'gexpandgroup'.
# 13.07.2017: Fixed narrow dropdown with hidden argument ellipsize = "none".
# 07.07.2017: Replaced 'droplist' with 'gcombobox'.
# 07.07.2017: Removed argument 'border' for 'gbutton'.
# 06.03.2017: Removed dead web page references.
# 01.11.2016: 'Probability' on y axis changed to 'Density'.
# 11.10.2016: Added controls for x and y axis range.
# 11.10.2016: No longer required to select a group if column Group is present.
# 19.09.2016: Fixed factor levels in group drop-down after change in calculatePeaks.
# 27.06.2016: Fixed 'bins' not saved.
# 16.06.2016: Implemented log option and number of bins.
# 19.05.2016: Fixed update of drop-down and information when selecting a new dataset.
# 29.04.2016: 'Save as' textbox expandable.
# 06.01.2016: Fixed theme methods not found and added more themes.
# 11.11.2015: Added importFrom ggplot2.

#' @title Plot Distribution
#'
#' @description
#' GUI simplifying the creation of distribution plots.
#'
#' @details Plot the distribution of data as cumulative distribution function,
#' probability density function, or count. First select a dataset, then select
#' a group (in column 'Group' if any), finally select a column to plot the distribution of.
#' It is possible to overlay a boxplot and to plot logarithms.
#' Various smoothing kernels and bandwidths can be specified.
#' The bandwidth or the number of bins can be specified for the histogram.
#' Automatic plot titles can be replaced by custom titles.
#' A name for the result is automatically suggested.
#' The resulting plot can be saved as either a plot object or as an image.
#' @param env environment in which to search for data frames and save result.
#' @param savegui logical indicating if GUI settings should be saved in the environment.
#' @param debug logical indicating printing debug information.
#' @param parent widget to get focus when finished.
#'
#' @export
#'
#' @importFrom utils help str head
#' @importFrom ggplot2 ggplot aes_string stat_ecdf geom_density ggplot_build
#'  geom_boxplot geom_segment geom_point labs theme_gray theme_bw
#'  theme_linedraw theme_light theme_dark theme_minimal theme_classic
#'  theme_void geom_histogram
#'
#' @return TRUE
#'
#' @seealso \code{\link{log}}, \code{\link{geom_density}}


plotDistribution_gui <- function(env = parent.frame(), savegui = NULL, debug = FALSE, parent = NULL) {

  # Global variables.
  .gData <- NULL
  .gDataName <- NULL
  .gPlot <- NULL
  .palette <- c(
    "Set1", "Set2", "Set3", "Accent", "Dark2",
    "Paired", "Pastel1", "Pastel2"
  )
  .defaultGroup <- "<Select group>"
  .defaultColumn <- "<Select column>"
  # Qualitative palette, do not imply magnitude differences between legend
  # classes, and hues are used to create the primary visual differences
  # between classes. Qualitative schemes are best suited to representing
  # nominal or categorical data.

  if (debug) {
    print(paste("IN:", match.call()[[1]]))
  }

  # Main window.
  w <- gwindow(title = "Plot distributions", visible = FALSE)

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
    print(help("plotDistribution_gui", help_type = "html"))
  })

  # FRAME 0 ###################################################################

  f0 <- gframe(
    text = "Dataset",
    horizontal = TRUE,
    spacing = 2,
    container = gv
  )

  f0g0 <- glayout(container = f0, spacing = 2)

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

  f0g0[1, 3] <- f0_samples_lbl <- glabel(text = " (0 rows)", container = f0g0)

  f0g0[2, 1] <- glabel(text = "Select group:", container = f0g0)
  f0g0[2, 2] <- f0_group_drp <- gcombobox(
    items = .defaultGroup,
    selected = 1, container = f0g0,
    ellipsize = "none"
  )
  f0g0[2, 3] <- f0_rows_lbl <- glabel(text = " (0 rows)", container = f0g0)

  f0g0[3, 1] <- glabel(text = "Select column:", container = f0g0)
  f0g0[3, 2] <- f0_column_drp <- gcombobox(
    items = .defaultColumn,
    selected = 1, container = f0g0,
    ellipsize = "none"
  )


  addHandlerChanged(dataset_drp, handler = function(h, ...) {
    val_obj <- svalue(dataset_drp)

    # Check if suitable.
    requiredCol <- NULL
    ok <- checkDataset(
      name = val_obj, reqcol = requiredCol,
      env = env, parent = w, debug = debug
    )

    if (ok) {

      # Load or change components.
      .gData <<- get(val_obj, envir = env)
      .gDataName <<- val_obj

      # Refresh column in drop lists.
      .refresh_column_drp()

      # Suggest name.
      svalue(f5_save_edt) <- paste(val_obj, "_ggplot", sep = "")

      # Get number of observations.
      svalue(f0_samples_lbl) <- paste(" (", nrow(.gData), " rows)", sep = "")

      # Get number of observations in subset.
      val <- svalue(f0_group_drp)
      if (length(val) > 0 && val %in% names(.gData)) {
        rows <- nrow(.gData[.gData$Group == val, ])
        svalue(f0_rows_lbl) <- paste(" (", rows, " rows)", sep = "")
      } else {
        svalue(f0_rows_lbl) <- " (0 rows)"
      }

      # Enable buttons.
      enabled(f7_ecdf_btn) <- TRUE
      enabled(f7_pdf_btn) <- TRUE
      enabled(f7_histogram_btn) <- TRUE
    } else {

      # Reset components.
      .gData <<- NULL
      svalue(f5_save_edt) <- ""
      svalue(f0_samples_lbl) <- " (0 rows)"
    }
  })

  addHandlerChanged(f0_group_drp, handler = function(h, ...) {
    val <- svalue(f0_group_drp)
    rows <- nrow(.gData[.gData$Group == val, ])

    # Update number of observations.
    svalue(f0_rows_lbl) <- paste(" (", rows, " rows)", sep = "")
  })

  addHandlerChanged(f0_column_drp, handler = function(h, ...) {

    # Enable buttons.
    enabled(f7_ecdf_btn) <- TRUE
    enabled(f7_pdf_btn) <- TRUE
    enabled(f7_histogram_btn) <- TRUE
  })

  # FRAME 1 ###################################################################

  f1 <- gframe(
    text = "Options",
    horizontal = FALSE,
    spacing = 2,
    container = gv
  )

  titles_chk <- gcheckbox(
    text = "Override automatic titles.",
    checked = FALSE, container = f1
  )


  addHandlerChanged(titles_chk, handler = function(h, ...) {
    .updateGui()
  })

  titles_group <- ggroup(
    container = f1, spacing = 1, horizontal = FALSE,
    expand = TRUE, fill = TRUE
  )

  # Legends
  glabel(text = "Plot title:", container = titles_group, anchor = c(-1, 0))
  title_edt <- gedit(expand = TRUE, fill = TRUE, container = titles_group)

  glabel(text = "X title:", container = titles_group, anchor = c(-1, 0))
  x_title_edt <- gedit(expand = TRUE, fill = TRUE, container = titles_group)

  glabel(text = "Y title:", container = titles_group, anchor = c(-1, 0))
  y_title_edt <- gedit(expand = TRUE, fill = TRUE, container = titles_group)


  f1g2 <- glayout(container = f1, spacing = 1)
  f1g2[1, 1] <- glabel(text = "Plot theme:", anchor = c(-1, 0), container = f1g2)
  items_theme <- c(
    "theme_grey()", "theme_bw()", "theme_linedraw()",
    "theme_light()", "theme_dark()", "theme_minimal()",
    "theme_classic()", "theme_void()"
  )
  f1g2[1, 2] <- f1_theme_drp <- gcombobox(
    items = items_theme,
    selected = 1,
    container = f1g2,
    ellipsize = "none"
  )

  # Boxplot.
  f1g3 <- glayout(container = f1, spacing = 1)
  f1g3[1, 1] <- f1_box_chk <- gcheckbox(
    text = "Overlay boxplot", checked = TRUE,
    container = f1g3
  )
  f1g3[1, 2] <- glabel(text = "Width of boxplot:", container = f1g3)
  f1g3[1, 3] <- f1_width_spn <- gspinbutton(
    from = 0, to = 1, by = 0.01, value = 0.25,
    container = f1g3
  )

  addHandlerChanged(f1_box_chk, handler = function(h, ...) {
    .updateGui()
  })

  # Transformation.
  f1g3[2, 1] <- f1_log_chk <- gcheckbox(text = "Transform to logarithms.", container = f1g3)
  f1g3[2, 2] <- glabel(text = "Base:", container = f1g3)
  f1g3[2, 3] <- f1_base_edt <- gedit(text = "2.718282", width = 8, container = f1g3)
  tooltip(f1_base_edt) <- paste(
    "Default is the natural logarithm, approximately 2.718282.",
    "Other common values are 10 for the common logarithm,", "and 2 for binary logarithms."
  )

  addHandlerChanged(f1_log_chk, handler = function(h, ...) {
    .updateGui()
  })

  f1e2 <- gexpandgroup(
    text = "Distribution function",
    horizontal = FALSE, container = f1
  )

  # Start collapsed.
  visible(f1e2) <- FALSE

  f1g4 <- glayout(container = f1e2, spacing = 1)

  f1_kernel <- c(
    "gaussian", "rectangular", "triangular", "epanechnikov",
    "biweight", "cosine", "optcosine"
  )
  f1g4[1, 1] <- glabel(text = "Smoothing kernel:", container = f1g4)
  f1g4[1, 2] <- f1_kernel_drp <- gcombobox(
    items = f1_kernel,
    selected = 1, container = f1g4,
    ellipsize = "none"
  )

  f1_adjust <- c(4, 2, 1, 0.5, 0.25)
  f1g4[2, 1] <- glabel(text = "Adjust bandwidth:", container = f1g4)
  f1g4[2, 2] <- f1_adjustbw_cbo <- gcombobox(
    items = f1_adjust,
    selected = 3, editable = TRUE,
    container = f1g4, ellipsize = "none"
  )

  f1e3 <- gexpandgroup(
    text = "Histogram",
    horizontal = FALSE, container = f1
  )

  # Start collapsed.
  visible(f1e3) <- FALSE

  f1g5 <- glayout(container = f1e3, spacing = 1)

  f1g5[1, 1] <- glabel(text = "Adjust binwidth:", container = f1g5)
  f1g5[1, 2] <- f1_binwidth_edt <- gedit(text = "", width = 6, container = f1g5)
  binwidth_tip <- paste(
    "The width of the bins. The default is to use 30 bins, ",
    "that cover the range of the data. You should always",
    "override this value, exploring multiple widths to",
    "find the best to illustrate your data.",
    "Leave empty to use 'bins'."
  )
  tooltip(f1_binwidth_edt) <- binwidth_tip
  f1g5[2, 1] <- glabel(text = "Number of bins:", container = f1g5)
  f1g5[2, 2] <- f1_bins_edt <- gedit(text = "30", width = 6, container = f1g5)
  tooltip(f1_bins_edt) <- "Overridden by binwidth. Defaults to 30."

  addHandlerKeystroke(f1_binwidth_edt, handler = function(h, ...) {
    .updateGui()
  })

  addHandlerChanged(f1_binwidth_edt, handler = function(h, ...) {
    .updateGui()
  })


  f1e4 <- gexpandgroup(text = "Axes", horizontal = FALSE, container = f1)

  # Start collapsed.
  visible(f1e4) <- FALSE

  #  f1g6 <- gframe(text = "", horizontal = FALSE, container = f1e4)

  glabel(
    text = "NB! Must provide both min and max value.",
    anchor = c(-1, 0), container = f1e4
  )

  f1g6 <- glayout(container = f1e4, spacing = 1)
  f1g6[1, 1:2] <- glabel(text = "Limit Y axis (min-max)", container = f1g6)
  f1g6[2, 1] <- f1g6_y_min_edt <- gedit(text = "", width = 5, container = f1g6)
  f1g6[2, 2] <- f1g6_y_max_edt <- gedit(text = "", width = 5, container = f1g6)

  f1g6[3, 1:2] <- glabel(text = "Limit X axis (min-max)", container = f1g6)
  f1g6[4, 1] <- f1g6_x_min_edt <- gedit(text = "", width = 5, container = f1g6)
  f1g6[4, 2] <- f1g6_x_max_edt <- gedit(text = "", width = 5, container = f1g6)

  # FRAME 7 ###################################################################

  f7 <- gframe(
    text = "Plot distribution",
    horizontal = TRUE,
    container = gv
  )

  f7_ecdf_btn <- gbutton(text = "CDF", container = f7)

  addHandlerChanged(f7_ecdf_btn, handler = function(h, ...) {
    val_column <- svalue(f0_column_drp)

    if (val_column == .defaultColumn) {
      gmessage(
        msg = "A data column must be specified!",
        title = "Error",
        icon = "error"
      )
    } else {
      enabled(f7_ecdf_btn) <- FALSE
      .plot(how = "cdf")
      enabled(f7_ecdf_btn) <- TRUE
    }
  })

  f7_pdf_btn <- gbutton(text = "PDF", container = f7)

  addHandlerChanged(f7_pdf_btn, handler = function(h, ...) {
    val_column <- svalue(f0_column_drp)

    if (val_column == .defaultColumn) {
      gmessage(
        msg = "A data column must be specified!",
        title = "Error",
        icon = "error"
      )
    } else {
      enabled(f7_pdf_btn) <- FALSE
      .plot(how = "pdf")
      enabled(f7_pdf_btn) <- TRUE
    }
  })

  f7_histogram_btn <- gbutton(text = "Histogram", container = f7)

  addHandlerChanged(f7_histogram_btn, handler = function(h, ...) {
    val_column <- svalue(f0_column_drp)

    if (val_column == .defaultColumn) {
      gmessage(
        msg = "A data column must be specified!",
        title = "Error",
        icon = "error"
      )
    } else {
      enabled(f7_histogram_btn) <- FALSE
      .plot(how = "histogram")
      enabled(f7_histogram_btn) <- TRUE
    }
  })

  # FRAME 5 ###################################################################

  f5 <- gframe(
    text = "Save as",
    horizontal = TRUE,
    spacing = 2,
    container = gv
  )

  glabel(text = "Name for result:", container = f5)

  f5_save_edt <- gedit(container = f5, expand = TRUE, fill = TRUE)

  f5_save_btn <- gbutton(text = "Save as object", container = f5)

  f5_ggsave_btn <- gbutton(text = "Save as image", container = f5)

  addHandlerClicked(f5_save_btn, handler = function(h, ...) {
    val_name <- svalue(f5_save_edt)

    # Change button.
    blockHandlers(f5_save_btn)
    svalue(f5_save_btn) <- "Processing..."
    unblockHandlers(f5_save_btn)
    enabled(f5_save_btn) <- FALSE

    # Save data.
    saveObject(
      name = val_name, object = .gPlot,
      parent = w, env = env, debug = debug
    )

    # Change button.
    blockHandlers(f5_save_btn)
    svalue(f5_save_btn) <- "Object saved"
    unblockHandlers(f5_save_btn)
  })

  addHandlerChanged(f5_ggsave_btn, handler = function(h, ...) {
    val_name <- svalue(f5_save_edt)

    # Save data.
    ggsave_gui(
      ggplot = .gPlot, name = val_name,
      parent = w, env = env, savegui = savegui, debug = debug
    )
  })

  # FUNCTIONS #################################################################

  .plot <- function(how) {

    # Get values.
    val_data <- .gData
    val_titles <- svalue(titles_chk)
    val_title <- svalue(title_edt)
    val_x_title <- svalue(x_title_edt)
    val_y_title <- svalue(y_title_edt)
    val_theme <- svalue(f1_theme_drp)
    val_group <- svalue(f0_group_drp)
    val_column <- svalue(f0_column_drp)
    val_kernel <- svalue(f1_kernel_drp)
    val_adjustbw <- as.numeric(svalue(f1_adjustbw_cbo))
    val_boxplot <- svalue(f1_box_chk)
    val_width <- svalue(f1_width_spn)
    val_binwidth <- as.numeric(svalue(f1_binwidth_edt))
    val_log <- svalue(f1_log_chk)
    val_base <- as.numeric(svalue(f1_base_edt))
    val_bins <- as.numeric(svalue(f1_bins_edt))
    val_xmin <- as.numeric(svalue(f1g6_x_min_edt))
    val_xmax <- as.numeric(svalue(f1g6_x_max_edt))
    val_ymin <- as.numeric(svalue(f1g6_y_min_edt))
    val_ymax <- as.numeric(svalue(f1g6_y_max_edt))

    if (debug) {
      print("val_titles")
      print(val_titles)
      print("val_title")
      print(val_title)
      print("val_x_title")
      print(val_x_title)
      print("val_y_title")
      print(val_y_title)
      print("val_kernel")
      print(val_kernel)
      print("val_column")
      print(val_column)
      print("str(val_data)")
      print(str(val_data))
      print("val_adjustbw")
      print(val_adjustbw)
      print("val_binwidth")
      print(val_binwidth)
      print("val_log")
      print(val_log)
      print("val_base")
      print(val_base)
      print("val_bins")
      print(val_bins)
      print("val_xmin")
      print(val_xmin)
      print("val_xmax")
      print(val_xmax)
      print("val_ymin")
      print(val_ymin)
      print("val_ymax")
      print(val_ymax)
    }

    # Check if data.
    if (!is.na(val_data) && !is.null(val_data)) {
      if (debug) {
        print("Before plot: str(val_data)")
        print(str(val_data))
        print(head(val_data))
      }

      # Get number of observations.
      nb <- nrow(val_data)

      # Get data for selected group.
      if ("Group" %in% names(val_data)) {
        if (val_group != .defaultGroup) {

          # Store nb of observations.
          nb0 <- nb

          # Subset according to group.
          val_data <- val_data[val_data$Group == val_group, ]

          # Update number of observations.
          nb <- nrow(val_data)

          # Show message.
          message(paste("Subset group = '", val_group,
            "', removed ", nb0 - nb, " rows.",
            sep = ""
          ))
        }

        message("No group selected.")
      }

      # Convert to numeric.
      if (!is.numeric(val_data[, val_column])) {
        val_data[, val_column] <- as.numeric(val_data[, val_column])
        message(paste(val_column, " converted to numeric."))
      }

      # Transform data.
      if (val_log) {
        # Calculate the logarithms using specified base.
        val_data[, val_column] <- log(val_data[, val_column], base = val_base)
        message("Transformed values to logarithms of base ", val_base, ".")
      }

      if (debug) {
        print("After subsetting (val_data)")
        print(str(val_data))
        print(head(val_data))
      }

      # Remove NA's
      if (any(is.na(val_data[, val_column]))) {

        # Store nb of observations.
        nb0 <- nb

        # Update number of observations.
        nb <- nrow(val_data[!is.na(val_data[val_column]), ])

        # Show message.
        message(paste("Removed ", nb0 - nb, " NA rows.", sep = ""))

        if (debug) {
          print("After subsetting (val_data)")
          print(str(val_data))
          print(head(val_data))
        }
      }

      # Create titles.
      if (val_titles) {
        if (debug) {
          print("Custom titles")
        }

        mainTitle <- val_title
        xTitle <- val_x_title
        yTitle <- val_y_title
      } else {
        if (debug) {
          print("Default titles")
        }

        # Different titles.
        if (how == "cdf") {
          mainTitle <- paste("Cumulative density function (",
            nb, " observations)",
            sep = ""
          )

          yTitle <- "Density"
        } else if (how == "pdf") {
          mainTitle <- paste("Probability density function (",
            nb, " observations)",
            sep = ""
          )

          yTitle <- "Density"
        } else if (how == "histogram") {
          mainTitle <- paste("Histogram (",
            nb, " observations)",
            sep = ""
          )

          yTitle <- "Count"
        } else {
          warning(paste("how=", how, "not implemented for titles!"))
        }

        # Different X axis depending on chosen column.
        if (val_column == "Height") {
          xTitle <- "Peak height (RFU)"
        } else if (val_column == "Size") {
          xTitle <- "Fragment size (bp)"
        } else if (val_column == "Data.Point") {
          xTitle <- "Data point"
        } else {
          xTitle <- val_column
        }
      }

      # Create plots.
      if (how == "cdf") {
        if (debug) {
          print("Create cdf plot")
        }

        # ECDP
        gp <- ggplot(data = val_data, aes_string(x = val_column))
        gp <- gp + stat_ecdf()
      } else if (how == "pdf") {
        if (debug) {
          print("Create pdf plot")
        }

        gp <- ggplot(data = val_data, aes_string(x = val_column))
        gp <- gp + geom_density(aes_string(x = val_column), kernel = val_kernel, adjust = val_adjustbw)
      } else if (how == "histogram") {
        if (debug) {
          print("Create Histogram")
        }

        # Create plot.
        gp <- ggplot(data = val_data, aes_string(x = val_column))

        # Binwidth overrides bins.
        if (!is.na(val_binwidth)) {
          gp <- gp + geom_histogram(binwidth = val_binwidth)
        } else {
          if (is.na(val_bins)) {
            val_bins <- 30
          }
          gp <- gp + geom_histogram(bins = val_bins)
        }
      } else {
        warning(paste("how=", how, "not implemented for plots!"))
      }

      if (debug) {
        print("Plot created")
      }

      # Overlay boxplot.
      if (val_boxplot) {
        if (debug) {
          print("Overlay boxplot")
        }

        # Extract information from plot:
        gb <- ggplot_build(gp)
        ywidth <- max(gb$data[[1]]$y, na.rm = TRUE) * (val_width / 2)
        ymean <- max(gb$data[[1]]$y, na.rm = TRUE) / 2

        # Create a normal boxplot.
        gbox <- ggplot(data = val_data, aes_string(x = 1, y = val_column))
        gbox <- gbox + geom_boxplot()

        # Extract information from boxplot.
        gb <- ggplot_build(gbox)
        xmax <- gb$data[[1]]$ymax
        xmin <- gb$data[[1]]$ymin
        left <- gb$data[[1]]$lower
        middle <- gb$data[[1]]$middle
        right <- gb$data[[1]]$upper
        dots <- unlist(gb$data[[1]]$outliers)

        val_box <- data.frame(
          xmin = xmin, xmax = xmax,
          ymin = ymean - ywidth, ymax = ymean + ywidth, ymean = ymean,
          left = left, middle = middle, right = right
        )


        if (debug) {
          print("val_box")
          print(val_box)
          print("dots")
          print(dots)
        }

        # Manually overlay a boxplot:
        # Add box.
        # Should work...
        #        gp <- gp + geom_polygon(data=val_box, aes_string(x = c("left","left","right","right"),
        #                                                         y = c("ymin","ymax","ymax","ymin")),
        #                                color=1, alpha=0)
        #        gp <- gp + geom_rect(data=val_box, aes_string(xmin = "left", xmax="right",
        #                                                      ymin = "ymin", ymax="ymax"),
        #                             color=1, alpha=0)
        # Add top.
        gp <- gp + geom_segment(data = val_box, aes_string(
          x = "left", y = "ymax",
          xend = "right", yend = "ymax"
        ))

        # Add bottom.
        gp <- gp + geom_segment(data = val_box, aes_string(
          x = "left", y = "ymin",
          xend = "right", yend = "ymin"
        ))

        # Add left.
        gp <- gp + geom_segment(data = val_box, aes_string(
          x = "left", y = "ymin",
          xend = "left", yend = "ymax"
        ))

        # Add right.
        gp <- gp + geom_segment(data = val_box, aes_string(
          x = "right", y = "ymin",
          xend = "right", yend = "ymax"
        ))

        # Add median.
        gp <- gp + geom_segment(data = val_box, aes_string(
          x = "middle", y = "ymin",
          xend = "middle", yend = "ymax"
        ))
        # Add whiskers.
        gp <- gp + geom_segment(data = val_box, aes_string(
          x = "xmin", y = "ymean",
          xend = "left", yend = "ymean"
        ))
        gp <- gp + geom_segment(data = val_box, aes_string(
          x = "xmax", y = "ymean",
          xend = "right", yend = "ymean"
        ))
        # Add outliers.
        out <- data.frame(x = dots, y = rep(ymean, length(dots)))
        gp <- gp + geom_point(data = out, aes_string(x = "x", y = "y"))

        if (debug) {
          print("Boxplot created")
        }
      } # End if boxplot.

      # Add titles.
      gp <- gp + labs(title = mainTitle, x = xTitle, y = yTitle, fill = NULL)

      # Apply theme.
      gp <- gp + eval(parse(text = val_theme))

      # Limit y axis.
      if (!is.na(val_ymin) && !is.na(val_ymax)) {
        val_y <- c(val_ymin, val_ymax)
      } else {
        val_y <- NULL
      }

      # Limit x axis.
      if (!is.na(val_xmin) && !is.na(val_xmax)) {
        val_x <- c(val_xmin, val_xmax)
      } else {
        val_x <- NULL
      }

      # Check if any axis limits.
      if (any(!is.null(val_y), !is.null(val_x))) {
        message(
          "Zoom plot xmin/xmax,ymin/ymax:",
          paste(val_x, collapse = "/"), ",",
          paste(val_y, collapse = "/")
        )

        # Zoom in without dropping observations.
        gp <- gp + coord_cartesian(xlim = val_x, ylim = val_y)
      }

      # plot.
      print(gp)

      # Store in global variable.
      .gPlot <<- gp

      # Change save button.
      svalue(f5_save_btn) <- "Save as object"
      enabled(f5_save_btn) <- TRUE
    } else {
      gmessage(
        msg = "Data frame is NULL or NA!",
        title = "Error",
        icon = "error"
      )
    }
  }

  # INTERNAL FUNCTIONS ########################################################

  .updateGui <- function() {

    # Override titles.
    val <- svalue(titles_chk)
    if (val) {
      enabled(titles_group) <- TRUE
    } else {
      enabled(titles_group) <- FALSE
    }

    # Boxplot dependent widgets.
    val <- svalue(f1_box_chk)
    if (val) {
      enabled(f1_width_spn) <- TRUE
    } else {
      enabled(f1_width_spn) <- FALSE
    }

    # Log dependent widgets.
    val <- svalue(f1_log_chk)
    if (val) {
      enabled(f1_base_edt) <- TRUE
    } else {
      enabled(f1_base_edt) <- FALSE
    }

    # Binwidth dependent widgets.
    val <- svalue(f1_binwidth_edt)
    if (nchar(val) == 0) {
      enabled(f1_bins_edt) <- TRUE
    } else {
      enabled(f1_bins_edt) <- FALSE
    }
  }

  .refresh_column_drp <- function() {
    if (debug) {
      print("Refresh group and column dropdown")
    }

    # Get data frames in global workspace.
    groups <- unique(as.character(.gData$Group))
    columns <- names(.gData)

    if (length(groups) > 0) {
      blockHandler(f0_group_drp)

      # Populate drop list.
      f0_group_drp[] <- c(.defaultGroup, groups)
      svalue(f0_group_drp, index = TRUE) <- 1

      unblockHandler(f0_group_drp)
    } else {
      blockHandler(f0_group_drp)

      # Reset drop list and select first item.
      f0_group_drp[] <- c(.defaultGroup)
      svalue(f0_group_drp, index = TRUE) <- 1

      unblockHandler(f0_group_drp)
    }


    if (!is.null(columns)) {
      blockHandler(f0_column_drp)

      # Populate drop list.
      f0_column_drp[] <- c(.defaultColumn, columns)
      svalue(f0_column_drp, index = TRUE) <- 1

      unblockHandler(f0_column_drp)
    } else {
      blockHandler(f0_column_drp)

      # Reset drop list and select first item.
      f0_column_drp[] <- c(.defaultColumn)
      svalue(f0_column_drp, index = TRUE) <- 1

      unblockHandler(f0_column_drp)
    }
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
      if (exists(".strvalidator_plotDistribution_gui_savegui", envir = env, inherits = FALSE)) {
        svalue(savegui_chk) <- get(".strvalidator_plotDistribution_gui_savegui", envir = env)
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
      if (exists(".strvalidator_plotDistribution_gui_title", envir = env, inherits = FALSE)) {
        svalue(title_edt) <- get(".strvalidator_plotDistribution_gui_title", envir = env)
      }
      if (exists(".strvalidator_plotDistribution_gui_title_chk", envir = env, inherits = FALSE)) {
        svalue(titles_chk) <- get(".strvalidator_plotDistribution_gui_title_chk", envir = env)
      }
      if (exists(".strvalidator_plotDistribution_gui_x_title", envir = env, inherits = FALSE)) {
        svalue(x_title_edt) <- get(".strvalidator_plotDistribution_gui_x_title", envir = env)
      }
      if (exists(".strvalidator_plotDistribution_gui_y_title", envir = env, inherits = FALSE)) {
        svalue(y_title_edt) <- get(".strvalidator_plotDistribution_gui_y_title", envir = env)
      }
      if (exists(".strvalidator_plotDistribution_gui_box", envir = env, inherits = FALSE)) {
        svalue(f1_box_chk) <- get(".strvalidator_plotDistribution_gui_box", envir = env)
      }
      if (exists(".strvalidator_plotDistribution_gui_kernel", envir = env, inherits = FALSE)) {
        svalue(f1_kernel_drp) <- get(".strvalidator_plotDistribution_gui_kernel", envir = env)
      }
      if (exists(".strvalidator_plotDistribution_gui_theme", envir = env, inherits = FALSE)) {
        svalue(f1_theme_drp) <- get(".strvalidator_plotDistribution_gui_theme", envir = env)
      }
      if (exists(".strvalidator_plotDistribution_gui_width", envir = env, inherits = FALSE)) {
        svalue(f1_width_spn) <- get(".strvalidator_plotDistribution_gui_width", envir = env)
      }
      if (exists(".strvalidator_plotDistribution_gui_binwidth", envir = env, inherits = FALSE)) {
        svalue(f1_binwidth_edt) <- get(".strvalidator_plotDistribution_gui_binwidth", envir = env)
      }
      if (exists(".strvalidator_plotDistribution_gui_bins", envir = env, inherits = FALSE)) {
        svalue(f1_bins_edt) <- get(".strvalidator_plotDistribution_gui_bins", envir = env)
      }
      if (exists(".strvalidator_plotDistribution_gui_log", envir = env, inherits = FALSE)) {
        svalue(f1_log_chk) <- get(".strvalidator_plotDistribution_gui_log", envir = env)
      }
      if (exists(".strvalidator_plotDistribution_gui_base", envir = env, inherits = FALSE)) {
        svalue(f1_base_edt) <- get(".strvalidator_plotDistribution_gui_base", envir = env)
      }

      if (debug) {
        print("Saved settings loaded!")
      }
    }
  }

  .saveSettings <- function() {

    # Then save settings if true.
    if (svalue(savegui_chk)) {
      assign(x = ".strvalidator_plotDistribution_gui_savegui", value = svalue(savegui_chk), envir = env)
      assign(x = ".strvalidator_plotDistribution_gui_title_chk", value = svalue(titles_chk), envir = env)
      assign(x = ".strvalidator_plotDistribution_gui_title", value = svalue(title_edt), envir = env)
      assign(x = ".strvalidator_plotDistribution_gui_x_title", value = svalue(x_title_edt), envir = env)
      assign(x = ".strvalidator_plotDistribution_gui_y_title", value = svalue(y_title_edt), envir = env)
      assign(x = ".strvalidator_plotDistribution_gui_box", value = svalue(f1_box_chk), envir = env)
      assign(x = ".strvalidator_plotDistribution_gui_kernel", value = svalue(f1_kernel_drp), envir = env)
      assign(x = ".strvalidator_plotDistribution_gui_theme", value = svalue(f1_theme_drp), envir = env)
      assign(x = ".strvalidator_plotDistribution_gui_width", value = svalue(f1_width_spn), envir = env)
      assign(x = ".strvalidator_plotDistribution_gui_binwidth", value = svalue(f1_binwidth_edt), envir = env)
      assign(x = ".strvalidator_plotDistribution_gui_bins", value = svalue(f1_bins_edt), envir = env)
      assign(x = ".strvalidator_plotDistribution_gui_log", value = svalue(f1_log_chk), envir = env)
      assign(x = ".strvalidator_plotDistribution_gui_base", value = svalue(f1_base_edt), envir = env)
    } else { # or remove all saved values if false.

      if (exists(".strvalidator_plotDistribution_gui_savegui", envir = env, inherits = FALSE)) {
        remove(".strvalidator_plotDistribution_gui_savegui", envir = env)
      }
      if (exists(".strvalidator_plotDistribution_gui_title_chk", envir = env, inherits = FALSE)) {
        remove(".strvalidator_plotDistribution_gui_title_chk", envir = env)
      }
      if (exists(".strvalidator_plotDistribution_gui_title", envir = env, inherits = FALSE)) {
        remove(".strvalidator_plotDistribution_gui_title", envir = env)
      }
      if (exists(".strvalidator_plotDistribution_gui_x_title", envir = env, inherits = FALSE)) {
        remove(".strvalidator_plotDistribution_gui_x_title", envir = env)
      }
      if (exists(".strvalidator_plotDistribution_gui_y_title", envir = env, inherits = FALSE)) {
        remove(".strvalidator_plotDistribution_gui_y_title", envir = env)
      }
      if (exists(".strvalidator_plotDistribution_gui_box", envir = env, inherits = FALSE)) {
        remove(".strvalidator_plotDistribution_gui_box", envir = env)
      }
      if (exists(".strvalidator_plotDistribution_gui_kernel", envir = env, inherits = FALSE)) {
        remove(".strvalidator_plotDistribution_gui_kernel", envir = env)
      }
      if (exists(".strvalidator_plotDistribution_gui_theme", envir = env, inherits = FALSE)) {
        remove(".strvalidator_plotDistribution_gui_theme", envir = env)
      }
      if (exists(".strvalidator_plotDistribution_gui_width", envir = env, inherits = FALSE)) {
        remove(".strvalidator_plotDistribution_gui_width", envir = env)
      }
      if (exists(".strvalidator_plotDistribution_gui_binwidth", envir = env, inherits = FALSE)) {
        remove(".strvalidator_plotDistribution_gui_binwidth", envir = env)
      }
      if (exists(".strvalidator_plotDistribution_gui_binws", envir = env, inherits = FALSE)) {
        remove(".strvalidator_plotDistribution_gui_binws", envir = env)
      }
      if (exists(".strvalidator_plotDistribution_gui_log", envir = env, inherits = FALSE)) {
        remove(".strvalidator_plotDistribution_gui_log", envir = env)
      }
      if (exists(".strvalidator_plotDistribution_gui_base", envir = env, inherits = FALSE)) {
        remove(".strvalidator_plotDistribution_gui_base", envir = env)
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

  # Update widget status.
  .updateGui()

  # Show GUI.
  visible(w) <- TRUE
  focus(w)
}
