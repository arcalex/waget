# WAGET

`waget` is for `web archive get`, a web archive collection update
automation tool.  (The name is a slight alteration of `wget`, the
popular tool for fetching stuff from the web.)

`waget` uses the Web Archive Systems API (WASAPI) to synchronize a copy
of a web archive collection with data from a remote web archive that
holds the files produced by a web crawler as well as triggers the
execution of actions on update (e.g., the execution of an indexing job).

This was initially part of Bibliotheca Alexandrina's work on preparing
the COVID-19 web archive collection by the International Internet
Preservation Consortium (IIPC) for publishing.

There are only 2 simple scripts at the moment:

- `list.sh` fetches the list of files in the collection
- `get.sh` starts the file transfer in parallel using `llx`

Both scripts expect Archive-It credentials to be in the `~/.netrc` file.

Web Archive Systems API (WASAPI):

https://github.com/WASAPI-Community/data-transfer-apis

See also "Find and download your WARC files with WASAPI":

https://support.archive-it.org/hc/en-us/articles/360015225051-Find-and-download-your-WARC-files-with-WASAPI

Please note that WASAPI, in this context, is not to be confused with the
Windows Audio Sesion API:

https://docs.microsoft.com/en-us/windows/win32/coreaudio/wasapi

`get.sh` uses `llx` for parallel execution:

https://github.com/arcalex/llx/
