LIMIT_MAX_RUNNING_DEFAULT = 16

# Use embedded JavaScript to declare _ and exports, so that they are only
# declared as local variables if they haven't been defined by the environment:
`if (require) {
	var _ = require('underscore');
}

if (typeof(window) != 'undefined' && typeof(exports) == 'undefined') {
	var exports = window.A_ = {};
}`

###
Most functions passed to Ascore's API have to be asynchronous. (Not really, but
they should expect a callback.) Use the functions below to wrap your synchronous
functions:
###

# Hopefully, these will be easily inline-able by the JIT compiler:
wrap0Arg = (f, ctx) -> (            cb) -> cb null, f.call ctx or @
wrap1Arg = (f, ctx) -> (a,          cb) -> cb null, f.call ctx or @, a
wrap2Arg = (f, ctx) -> (a, b,       cb) -> cb null, f.call ctx or @, a, b
wrap3Arg = (f, ctx) -> (a, b, c,    cb) -> cb null, f.call ctx or @, a, b, c
wrap4Arg = (f, ctx) -> (a, b, c, d, cb) -> cb null, f.call ctx or @, a, b, c, d

exports.wrap0Arg = exports.w0A = wrap0Arg
exports.wrap1Arg = exports.w1A = wrap1Arg
exports.wrap2Arg = exports.w2A = wrap2Arg
exports.wrap3Arg = exports.w3A = wrap3Arg
exports.wrap4Arg = exports.w4A = wrap4Arg

# And the general solution:
exports.wrapFun =
wrapFun = (fun, ctx = null) ->
	(args..., cb) ->
		cb null, fun.apply ctx or @, args

# Catches any errors and passes them to the callback:
exports.wrapFunWithCatch =
wrapFunWithCatch = (fun, ctx = null) ->
	(args..., cb) ->
		try
			val = fun.apply ctx or @, args
		
		catch err
			caught = yes
			
			cb err, null
		
		if not caught
			cb null, val


exports.each =
each = (arr, doItem, doneCb) ->			
	if not _.isFunction doneCb # Valid map callback?
		throw new InvalidDoneCbError "Done callback not a valid function: #{doneCb}"
		
	else if not _.isFunction doItem # Valid item callback?
		doneCb (new InvalidItemCbError "Item callback not a valid function: #{doItem}")
	
	else if not _.isArray(arr) and not _.isObject(arr) # Valid array or hash?
		doneCb (new InvalidArrError "Not a valid array or hash: #{arr}")
		
	else if _.isFunction arr
		arr (err, arr) ->
			if err
				doneCb err
			else if not _.isArray(arr) and not _.isObject(arr)
				doneCb (new InvalidArrError "Not a valid array or hash: #{arr}")
			else
				_each arr, doItem, doneCb
	else 
		_each arr, doItem, doneCb

exports.sloppyEach =
sloppyEach = (arr, doItem, doneCb) ->
	if _.isFunction arr
		arr (err, arr) ->
			if err
				doneCb err
			else
				_each arr, doItem, doneCb
	else
		_each arr, doItem, doneCb

_each = (arr, doItem, doneCb) ->
	if _.isArray arr
		waiting = arr.length
	else
		waiting = _.keys(arr).length

	if not waiting # Edge case: arr is an empty array or hash
		doneCb null

	else
		errord = no
		
		_.each arr, (item, i) ->
			if errord
				return
				
			doItem item, i, (err) ->
				if err
					errord = yes
				
					doneCb err
			
				else if not --waiting
					doneCb null

makeEacherFun = (each) ->
	(arr, doItem = null) ->
		[arr, doItem] = [null, arr]
		
		if not _.isFunction doItem # Valid item callback?
			throw new InvalidItemCbError "Item callback not a valid function: #{doItem}"
		
		if arr
			(doneCb) ->
				each arr, doItem, doneCb
		else
			(arr, doneCb) ->
				each arr, doItem, doneCb


exports.eacher       = eacher       = makeEacherFun each
exports.sloppyEacher = sloppyEacher = makeEacherFun sloppyEach


exports.map =
map = (arr, vals, doItem, mapCb = null) ->
	if mapCb is null
		[vals, doItem, mapCb] = [null, vals, doItem]
		
	if not _.isFunction mapCb # Valid map callback?
		throw new InvalidMapCbError "Callback for mapped values not a valid function: #{mapCb}"
	
	else if not _.isFunction doItem # Valid item callback?
		mapCb (new InvalidItemCbError "Item callback not a valid function: #{doItem}"), null
	
	else if not _.isArray(arr) and not _.isObject(arr) # Valid array or hash?
		mapCb (new InvalidArrError "Not a valid array or hash: #{arr}"), null
	
	else if _.isFunction arr
		arr (err, arr) ->
			if err
				mapCb err, null
				
			else if not _.isArray(arr) and not _.isObject(arr)
				mapCb (new InvalidArrError "Not a valid array or hash: #{arr}"), null
				
			else if vals and _.isArray(arr)
				mapCb (new InvalidValsError "No existing values may be provided when mapping an array"), null
		
			else
				_map arr, vals, doItem, mapCb
				
	else if vals and _.isArray(arr)
		mapCb (new InvalidValsError "No existing values may be provided when mapping an array"), null
	else
		_map arr, vals, doItem, mapCb

exports.sloppyMap =
sloppyMap = (arr, vals, doItem, mapCb = null) ->
	if mapCb is null
		[vals, doItem, mapCb] = [null, vals, doItem]
	
	if _.isFunction arr
		arr (err, arr) ->
			if err
				mapCb err, null
			else
				_map arr, vals, doItem, mapCb
	else
		_map arr, vals, doItem, mapCb 

_map = (arr, vals, doItem, mapCb) ->
	vals = if _.isArray(arr) then [] else vals or {}

	_each arr, (item, i, doneCb) ->
		doItem item, (err, val) ->
			if err
				doneCb err
			
			else
				vals[i] = val
				
				doneCb null
	
	, (err) ->
		if err
			mapCb err, null
			
		else
			mapCb null, vals
	
	vals # Reference to unfinished value, (almost) never use this!

makeMapperFun = (map) ->
	(arr, vals = null, doItem = null) ->
		if doItem is null
			if vals is null
				[arr, vals, doItem] = [null, null, arr]
			else
				[arr, vals, doItem] = [arr, null, vals]
		
		if not _.isFunction doItem # Valid item callback?
			throw new InvalidItemCbError "Item callback not a valid function: #{doItem}"
		
		if vals
			if arr
				(mapCb) ->
					map arr, vals, doItem, mapCb
			else
				(arr, mapCb) ->
					map arr, vals, doItem, mapCb
		else
			if arr
				(vals, mapCb = null) ->
					if mapCb is null
						[vals, mapCb] = [null, vals]
					
					map arr, vals, doItem, mapCb
			else
				(arr, vals, mapCb = null) ->
					if mapCb is null
						[vals, mapCb] = [null, vals]
					
					map arr, vals, doItem, mapCb

exports.mapper       = mapper       = makeMapperFun map
exports.sloppyMapper = sloppyMapper = makeMapperFun sloppyMap


exports.push =
push = (arr, doItem, pushItem, doneCb) ->
	if not _.isFunction doneCb
		throw new InvalidDoneCbError "Done callback not a valid function: #{doneCb}"
	
	else if not _.isFunction pushItem
		doneCb (new InvalidPushItemError "Push-item-function not a valid function")
		
	else if not _.isFunction doItem # Valid item callback?
		doneCb (new InvalidItemCbError "Item callback not a valid function: #{doItem}")
	
	else if not _.isArray arr # Valid array?
		doneCb (new InvalidArrError "Not a valid array: #{arr}")
	
	_push arr, doItem, pushItem, doneCb

exports.sloppyPush =
_push = (arr, doItem, pushItem, doneCb) ->
	offset  = 0
	vals    = []
	waiting = arr.length
	
	if not waiting
		doneCb null
	
	_.each arr, (item, i) ->
		doItem item, (err, val) ->
			if err
				doneCb err
				return
			
			if val is undefined
				throw new InvalidItemCbError "Push item iterator should never give back undefined, use null instead"
			
			vals[ i - offset ] = val
				
			while vals[0] isnt undefined
				++offset
				
				pushItem vals.shift(), (err) ->
					if err
						doneCb err
					
					else if not --waiting
						doneCb null


exports.sloppySlide =
_slide = (arr, pushItemFuns..., doneCb) ->
	vals    = [ arr ]
	offsets = [ 0 ]
	
	waiting = arr.length
	
	while vals.length < pushItemFuns.length
		vals.push     []
		offsets.push  0
		
		waiting += arr.length
	
	_.each pushItemFuns, (pushItem, i) ->
		_.each vals[i], (item, j) ->
			pushItem item, (err, val) ->
				if err
					doneCb err, null
				
				vals[i][j] 
				
				if not --waiting
					doneCb null

exports.eachPair =
eachPair = (arr, doPair, eachPairCb) ->
	errord = no
	
	waiting = Math.ceil( arr.length / 2 )
	if not waiting
		eachPairCb null, []
		return
	
	vals = []
	i = 0
	while i < arr.length
		do (i) ->
			if errord
				return
			
			a = arr[i]
			b = if i + 1 < arr.length then arr[ i + 1 ] else undefined
			
			doPair a, b, i, (err) ->
				if err
					errord = yes
			
					eachPairCb err
				
				else
					if not --waiting
						eachPairCb null
		i += 2

exports.mapPairs =
mapPairs = (arr, doPair, mapPairsCb) ->
	vals = []
	eachPair arr, (a, b, i, cb) ->
		doPair a, b, (err, val) ->
			vals[ i / 2 ] = val
			cb null
	
	, (err) ->
		if err
			mapPairsCb err,  null
		else
			mapPairsCb null, vals


###
DISCLAIMER: Unless the existence of this function is justified (over using an
async map and a regular reduce), it is expected to be removed in a later
release. Use at your own risk!
###
exports.reduce =
reduce = (arr, defaultVal, combine, reduceCb = null) ->
	if reduceCb is null
		[defaultVal, combine, reduceCb] = [undefined, defaultVal, combine]
		
	if not _.isFunction reduceCb
		throw new InvalidReduceCbError "Callback for reduced value not a valid function: #{reduceCb}"
	else if not _.isFunction combine
		reduceCb (new InvalidCombineFunError "Combine function not a valid function: #{combine}"), null
	else if not _.isArray arr
		reduceCb (new InvalidArrError "Not a valid array: #{arr}"), null
	else
		_reduce arr, defaultVal, combine, reduceCb

_reduce = (arr, defaultVal, combine, reduceCb, run = 0) ->
	if arr.length is 0
		reduceCb null, defaultVal
		return
	
	vals = []
	eachPair arr, (a, b, i, cb) ->
		if b is undefined
			if defaultVal is undefined
				vals[ i / 2 ] = a
				
				cb null
				return
				
			else
				b = defaultVal
		
		combine a, b, run, (err, val) ->
			if err
				cb err
			else
				vals[ i / 2 ] = val
				
				cb null
	
	, (err) ->
		if err
			reduceCb err, null
		else
			if vals.length is 1
				reduceCb null, vals[0]
			else
				_reduce vals, defaultVal, combine, reduceCb, run + 1

exports.reducer =
reducer = (defaultVal, combine) ->
	(arr, reduceCb) ->
		reduce arr, defaultVal, combine, reduceCb


exports.filter =
filter = (arr, doItem, filterCb) ->
	if not _.isFunction filterCb # Valid map callback?
		throw new InvalidFilterCbError "Callback for filtered values not a valid function: #{filterCb}"
		
	else if not _.isFunction doItem # Valid item callback?
		filterCb (new InvalidItemCbError "Item callback not a valid function: #{doItem}"), null
	
	else if not _.isArray(arr) and not _.isObject(arr) # Valid array or hash?
		filterCb (new InvalidArrError "Not a valid array or hash: #{arr}"), null
		
	else if _.isFunction arr
		arr (err, arr) ->
			if err
				filterCb err, null
				
			else if not _.isArray(arr) and not _.isObject(arr) # Valid array or hash?
				filterCb (new InvalidArrError "Not a valid array or hash: #{arr}"), null
				
			else
				_filter arr, doItem, filterCb
	else
		_filter arr, doItem, filterCb

exports.sloppyFilter =
sloppyFilter = (arr, doItem, filterCb) ->
	if _.isFunction arr
		arr (err, arr) ->
			if err
				filterCb err, null
			else
				_filter arr, doItem, filterCb
	else
		_filter arr, doItem, filterCb

_filter = (arr, doItem, filterCb) ->
	vals = if _.isArray(arr) then [] else {}
	
	_each arr, (item, i, doneCb) ->
		doItem item, (err, keep) ->
			if err
				doneCb err
			
			else
				if keep then vals[i] = item
			
				doneCb null
			
	, (err) ->
		if err
			filterCb err, null
		
		else
			if _.isArray arr
				vals = _.filter vals, (val) -> val != undefined
			
			filterCb null, vals
	
	vals # Reference to unfinished value, (almost) never use this!


makeFiltererFun = (filter) ->
	(doItem) ->
		if not _.isFunction doItem # Valid item callback?
			throw new InvalidItemCbError "Item callback not a valid function: #{doItem}"
	
		(arr, filterCb) ->
			filter arr, doItem, filterCb

exports.filterer       = filterer       = makeFiltererFun filter
exports.sloppyFilterer = sloppyFilterer = makeFiltererFun sloppyFilter


collectItem = (item, valCb) ->
	if _.isFunction item
		item valCb
	else
		valCb null, item
		
fcollectItem = (item, valCb) ->
	if not _.isFunction item
		valCb (new InvalidFCollectItem "All items passed to fcollect/flob must be functions, got: #{item}"), null
	else
		item valCb

exports.collect  =  collect = mapper  collectItem
exports.fcollect = fcollect = mapper fcollectItem

exports.collector  =  collector = (vals = {}) ->
	mapper null, vals,  collectItem
exports.fcollector = fcollector = (vals = {}) ->
	mapper null, vals, fcollectItem


makeLobFun = (collect) ->
	(vals, lobCb) ->
		collect vals, (err, vals) ->
			lobCb.call vals, err # Make values accessible through this in callback
		
exports.lob  =  lob = makeLobFun  collect
exports.flob = flob = makeLobFun fcollect

exports.lobber  =
lobber = (ctx = {}) ->
	makeLobFun  collector ctx
exports.flobber =
flobber = (ctx = {}) ->
	makeLobFun fcollector ctx


exports.limit =
limit = (maxRunning, fun = null) ->
	if fun is null
		[maxRunning, fun] = [LIMIT_MAX_RUNNING_DEFAULT, maxRunning]
	
	running = 0
	
	ctxQueue = []
	argQueue = []
	
	tryFun = (ctx, args) ->
		wrapCb ctx, args
		
		if running < maxRunning
			applyFun ctx, args
		else
			ctxQueue.push ctx
			argQueue.push args
	
	wrapCb = (ctx, args) ->
		cb = args.pop()
		
		args.push (args...) ->
			running--
			
			if argQueue.length
				applyFun ctxQueue.shift(), argQueue.shift()
			
			cb.apply ctx, args
	
	applyFun = (ctx, args) ->
		running++
		
		fun.apply ctx, args
	
	(args...) ->
		tryFun @, args


exports.sequence = exports.seq =
sequence = (funs..., doneOrErrCb) ->
	_sequence funs, doneOrErrCb, [], {}

exports.bindSequenceFunction = exports.bindSeqFun =
bindSeqFun = (ctx) ->
	(funs..., doneOrErrCb) ->
		_sequence funs, doneOrErrCb, [], ctx

exports.bindSequence =
bindSeq = (ctx, funs..., doneOrErrCb) ->
	_sequence funs, doneOrErrCb, [], ctx

exports.sequencer = exports.seqer =
sequencer = (funs...) ->
	(args..., doneOrErrCb) ->
		_funs = funs.slice 0 # Copy array
		
		_sequence _funs, doneOrErrCb, args, {}

exports.bindSequencer = exports.bindSeqer =
bindSeqer = (ctx, funs...) ->
	(args..., doneOrErrCb) ->
		_funs = funs.slice 0 # Copy array
		
		_sequence _funs, doneOrErrCb, args, ctx

exports.decorateWithSequencer = exports.decSeqer =
decSeqer = (funs...) ->
	(args..., doneOrErrCb) ->
		_funs = funs.slice 0 # Copy array
		
		_sequence _funs, doneOrErrCb, args, @

_sequence = (funs, doneOrErrCb, args, ctx) ->
	if fun = funs.shift()
		fun.apply ctx, args.concat [ (err, args...) ->
			if err
				doneOrErrCb.call ctx, err
			else
				_sequence funs, doneOrErrCb, args, ctx
		]
	else
		doneOrErrCb.apply ctx, [ null ].concat args


exports.chainTriggersTo =
chainTriggersTo = (checkForErr, doneCb = null, doneCbCtx = null) ->
	if doneCbCtx is null
		if doneCb is null
			[checkForErr, doneCb] = [yes, checkForErr]
		
		else if _.isFunction checkForErr
			[checkForErr, doneCb, doneCbCtx] = [yes, checkForErr, doneCb]
		
	waiting = 0
	
	(_checkForErr = checkForErr, fun = null, ctx = null) ->
		if ctx is null and _.isFunction _checkForErr
			[_checkForErr, fun, ctx] = [checkForErr, _checkForErr, fun]
		
		waiting++
		
		hasFired = no
		
		if fun
			errord = no
			
			(args...) ->
				# Wrap function body in timeout so it won't execute before all
				# triggers have been set synchronously:
				setTimeout ->
					if hasFired
						return
					else
						hasFired = yes
					
					if _checkForErr
						# Remove error argument and pass any errors to doneCb(),
						# if enabled:
						if err = args.pop()
							doneCb err
					else
						# If automagical error-checking is not enabled, add an
						# optional callback to the arguments for passing errors
						# to:
						args.push (err) ->
							if err
								errord = yes
							
								doneCb err
					
					fun.apply ctx, args
				
					if not errord and not --waiting
						doneCb.call doneCbCtx, null
				, 0
		else
			(err) ->
				# Wrap function body in timeout so it won't execute before all
				# triggers have been set synchronously:
				setTimeout ->
					if hasFired
						return
					else
						hasFired = yes
				
					if _checkForErr and err
						doneCb.call doneCbCtx, err
				
					else if not --waiting
						doneCb.call doneCbCtx, null
				, 0


exports.chainBindingsTo = (checkForErr, doneCb = null, doneCbCtx) ->
	if doneCb is null
		[checkForErr, doneCb] = [no, checkForErr]
		
	else if doneCbCtx is null and _.isFunction checkForErr
		[checkForErr, doneCb, doneCbCtx] = [no, checkForErr, doneCb]
	
	doneCbFired = 0
	bindingsFired = []
	currentBindingIndex = 0
	
	lastErrFireCount = 0
	
	fireDoneCb = (err) ->
		doneCbFired++
		
		doneCb err
	
	(_checkForErr = checkForErr, fun = null, ctx = null) ->
		bindingIndex = currentBindingIndex++
		
		bindingsFired[bindingIndex] = 0
		
		if fun
			(args...) ->
				# Wrap function body in timeout so it won't execute before all
				# triggers have been set synchronously:
				setTimeout ->
					fun.apply ctx, args
				
					fired = ++bindingsFired[bindingIndex]
				
					if fired is lastErrFireCount
						return
				
					if _checkForErr
						# Remove error argument and pass any errors to doneCb(),
						# if enabled:
						if err = args.pop()
							fireDoneCb err
							return
					else
						# If automagical error-checking is not enabled, add an
						# optional callback to the arguments for passing errors
						# to:
						args.push (err) ->
							if err
								lastErrFireCount = fired
							
								fireDoneCb err
				
					if doneCbFired < Math.min.apply null, bindingsFired
						fireDoneCb null
				, 0
				
		else
			(err) ->
				# Wrap function body in timeout so it won't execute before all
				# triggers have been set synchronously:
				setTimeout ->
					fired = ++bindingsFired[bindingIndex]
				
					if fired is lastErrFireCount
						return
					
					if err
						lastErrFireCount = fired
					
						fireDoneCb err
				
					else if doneCbFired < Math.min.apply null, bindingsFired
						fireDoneCb null
				, 0	
					

exports.Error = class AError extends Error
	constructor : (@message) ->
		Error.call @, message
						
		Error.captureStackTrace @, arguments.callee

exports.InvalidDoneCbError     = class InvalidDoneCbError     extends AError
exports.InvalidMapCbError      = class InvalidMapCbError      extends AError
exports.InvalidReduceCbError   = class InvalidReduceCbError   extends AError
exports.InvalidItemCbError     = class InvalidItemCbError     extends AError
exports.InvalidPushItemError   = class InvalidPushItemError   extends AError
exports.InvalidCombineFunError = class InvalidCombineFunError extends AError
exports.InvalidArrError        = class InvalidArrError        extends AError
exports.InvalidValsError       = class InvalidValsError       extends AError
exports.InvalidFilterCbError   = class InvalidFilterCbError   extends AError
exports.InvalidFCollectItem    = class InvalidFCollectItem    extends AError
