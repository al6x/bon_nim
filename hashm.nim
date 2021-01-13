import hashes

export hashes


# autohash -----------------------------------------------------------------------------------------
proc autohash*[T: tuple|object](o: T): Hash =
  for f in o.fields: result = result !& f.hash
