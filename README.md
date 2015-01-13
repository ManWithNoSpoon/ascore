Ascore provides aynchronous versions/analogues of each, map and filter. It also
provides utility functions for managing callbacks.

EACH

	fs = require 'fs'
	_  = require 'underscore'
	A_ = require 'ascore'
	
	# Read and print all files in the current directory, in no particular order:
	path = "."
	A_.each _.partial(fs.readDir, path), (fileName, i, doneCb) ->
		fs.readFile "#{path}/#{fileName}", (err, txt) ->
			console.log txt
			
			doneCb null
	
	, (err) ->
		console.log err or "Done!"


MAP

	# Print an array with the contents of all files in the current directory:
	path = "."
	A_.map _.partial(fs.readDir, path), (fileName, valCb) ->
		fs.readFile "#{path}/fileName", valCb
	
	, (err, vals) ->
		console.log err or vals


COLLECT

	pth = require 'path'
	
	# Print a hash containing various info about a file:
	path = "/path/to/file"
	A_.collect {
		# Fixed value, left untouched by collect():
		path      : path
		
		# Fixed values generated on the spot, left untouched by collect():
		fileName  : pth.basename path
		extension : pth.extname  path
		
		# Values generated asynchronously, replaced with the result of the
		# function passed to collect():
		stat      : (cb) -> fs.stat,     path, cb
		contents  : (cb) -> fs.readFile, path, cb
		
	}, (err, fileInfo) ->
		console.log err or fileInfo

COLLECTOR

	readPath = (path, pathInfoCb) ->
		collect = A_.collector()

		collect {
			stat : _.partial fs.stat, path
	
		}, (err, vals) ->
			if err
				pathInfoCb err, null
	
			else then collect {
				contents : if vals.stat.isdirectory()
					_.partial A_.map, _.partial(fs.readDir, path), (fileName, cb) ->
						readPath, "#{path}/#{fileName}"
				else
					_.partial fs.readFile, path

			}, pathInfoCb

