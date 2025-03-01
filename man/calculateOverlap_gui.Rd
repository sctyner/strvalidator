% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/calculateOverlap_gui.r
\name{calculateOverlap_gui}
\alias{calculateOverlap_gui}
\title{Calculate Bins Overlap}
\usage{
calculateOverlap_gui(env = parent.frame(), savegui = NULL,
  debug = TRUE, parent = NULL)
}
\arguments{
\item{env}{environment in which to search for data frames and save result.}

\item{savegui}{logical indicating if GUI settings should be saved in the environment.}

\item{debug}{logical indicating printing debug information.}

\item{parent}{widget to get focus when finished.}
}
\value{
TRUE
}
\description{
GUI wrapper for the \code{\link{calculateOverlap}} function.
}
\details{
By analysis of the bins overlap between dye channels a measure of
the risk for spectral pull-up artefacts can be obtain. The default result
is a matrix with the total bins overlap in number of base pairs. If an allele
frequency database is provided the overlap at each bin is multiplied with the
frequency of the corresponding allele. If no frequence exist for that allele
a frequency of 5/2N will be used. X and Y alleles is given the frequency 1.
A scoring matrix can be supplied to reduce the effect by spectral distance,
meaning that overlap with the neighboring dye can be counted in full (100%)
while a non neighbor dye get its overlap reduced (to e.g. 10%).
}
\seealso{
\code{\link{calculateOverlap}}
}
