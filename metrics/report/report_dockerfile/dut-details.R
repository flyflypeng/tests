#!/usr/bin/env Rscript
# Copyright (c) 2018 Intel Corporation
#
# SPDX-License-Identifier: Apache-2.0

# Display details for the 'Device Under Test', for all data sets being processed.

suppressMessages(suppressWarnings(library(tidyr)))	# for gather().
library(tibble)
suppressMessages(suppressWarnings(library(plyr)))	# rbind.fill
							# So we can plot multiple graphs
library(gridExtra)					# together.
suppressMessages(suppressWarnings(library(ggpubr)))	# for ggtexttable.
suppressMessages(library(jsonlite))			# to load the data.

render_dut_details <- function() {
	# A list of all the known results files we might find the information inside.
	resultsfiles=c(
		"boot-times.json",
		"footprint-busybox-ksm.json",
		"footprint-elasticsearch-ksm.json",
		"footprint-mysql-ksm.json",
		"memory-footprint.json",
		"memory-footprint-ksm.json",
		"fio-randread-16k.json",
		"fio-randread-32k.json",
		"fio-randread-4k.json",
		"fio-randread-64k.json",
		"fio-randread-8k.json",
		"fio-randwrite-16k.json",
		"fio-randwrite-32k.json",
		"fio-randwrite-4k.json",
		"fio-randwrite-64k.json",
		"fio-randwrite-8k.json"
		)

	data=c()
	stats=c()
	stats_names=c()
	datasetname=c()

	# For each set of results
	for (currentdir in resultdirs) {
		count=1
		dirstats=c()
		for (resultsfile in resultsfiles) {
			fname=paste(inputdir, currentdir, resultsfile, sep="/")
			if ( !file.exists(fname)) {
				next
			}

			# Derive the name from the test result dirname
			datasetname=basename(currentdir)

			# Import the data
			fdata=fromJSON(fname)

			if (length(fdata$'kata-env') != 0 ) {
				# We have kata-runtime data
				dirstats=tibble("Run Ver"=as.character(fdata$'kata-env'$Runtime$Version$Version$Semver))
				dirstats=cbind(dirstats, "Run SHA"=as.character(fdata$'kata-env'$Runtime$Version$Version$Commit))

				pver=as.character(fdata$'kata-env'$Proxy$Version$Semver)
				pver=sub("^[[:alpha:][:blank:]-]*", "", pver)
				# uncomment if you want to drop the commit sha as well
				#pver=sub("([[:digit:].]*).*", "\\1", pver)
				dirstats=cbind(dirstats, "Proxy Ver"=pver)

				# Trim the shim string
				sver=as.character(fdata$'kata-env'$Shim$Version$Semver)
				sver=sub("^[[:alpha:][:blank:]-]*", "", sver)
				# uncomment if you want to drop the commit sha as well
				#sver=sub("([[:digit:].]*).*", "\\1", sver)
				dirstats=cbind(dirstats, "Shim Ver"=sver)

				# Default QEMU ver string is far too long and noisy - trim.
				hver=as.character(fdata$'kata-env'$Hypervisor$Version)
				hver=sub("^[[:alpha:][:blank:]]*", "", hver)
				hver=sub("([[:digit:].]*).*", "\\1", hver)
				dirstats=cbind(dirstats, "Hyper Ver"=hver)

				iver=as.character(fdata$'kata-env'$Image$Path)
				iver=sub("^[[:alpha:]/-]*", "", iver)
				dirstats=cbind(dirstats, "Image Ver"=iver)

				kver=as.character(fdata$'kata-env'$Kernel$Path)
				kver=sub("^[[:alpha:]/-]*", "", kver)
				dirstats=cbind(dirstats, "Guest Krnl"=kver)

				dirstats=cbind(dirstats, "Host arch"=as.character(fdata$'kata-env'$Host$Architecture))
				dirstats=cbind(dirstats, "Host Distro"=as.character(fdata$'kata-env'$Host$Distro$Name))
				dirstats=cbind(dirstats, "Host DistVer"=as.character(fdata$'kata-env'$Host$Distro$Version))
				dirstats=cbind(dirstats, "Host Model"=as.character(fdata$'kata-env'$Host$CPU$Model))
				dirstats=cbind(dirstats, "Host Krnl"=as.character(fdata$'kata-env'$Host$Kernel))
				dirstats=cbind(dirstats, "runtime"=as.character(fdata$test$runtime))

				break
			} else {
				if (length(fdata$'runc-env') != 0 ) {
					dirstats=tibble("Run Ver"=as.character(fdata$'runc-env'$Version$Semver))
					dirstats=cbind(dirstats, "Run SHA"=as.character(fdata$'runc-env'$Version$Commit))
					dirstats=cbind(dirstats, "runtime"=as.character(fdata$test$runtime))
				} else {
					dirstats=tibble("runtime"="Unknown")
				}
				break
			}
		}

		if ( length(dirstats) == 0 ) {
			next
		}

		# use plyr rbind.fill so we can combine disparate version info frames
		stats=rbind.fill(stats, dirstats)
		stats_names=rbind(stats_names, datasetname)
	}

	if ( length(stats) == 0 ) {
		cat("No system data found\n\n")
		return()
	}

	rownames(stats) = stats_names

	# Rotate the tibble so we get data dirs as the columns
	spun_stats = as_tibble(cbind(What=names(stats), t(stats)))

	# Build us a text table of numerical results
	stats_plot = suppressWarnings(ggtexttable(data.frame(spun_stats, check.names=FALSE),
		theme=ttheme(base_size=6),
		rows=NULL
		))

	# It may seem odd doing a grid of 1x1, but it should ensure we get a uniform format and
	# layout to match the other charts and tables in the report.
	master_plot = grid.arrange(
		stats_plot,
		nrow=1,
		ncol=1 )
}

render_dut_details()
