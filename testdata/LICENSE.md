# Licence record for `testdata/`

This directory is new in this fork and it is not covered by a single licence.
Material is licensed by its own file, so the two kinds of file here are named
separately and neither is described by the other's terms.

## `geodtest-cases.txt` — upstream's grant

Its 240 numbers are transcribed from `tests/geodtest.c` of geographiclib-c
`v2.2`, commit `321c9a61359661fc2afa650dc888f5b1f5652443`, and that file
carries upstream's own copyright notice at `tests/geodtest.c:7`:

```
Copyright (c) Charles Karney (2015-2025) <karney@alum.mit.edu> and licensed
under the MIT/X11 License.
```

The file `geodtest-cases.txt` repeats that notice in its own header, so the
notice travels with the transcription as the MIT licence requires. The grant
itself is the same one upstream ships at `LICENSE.txt` in the repository root,
reproduced verbatim below. Nothing here narrows it, re-grants it or restates it
in other words; a downstream may rely on upstream's terms directly, and the root
`LICENSE.txt` is the authoritative copy.

The MIT License (MIT).

Copyright (c) 2012-2025, Charles Karney

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without
restriction, including without limitation the rights to use, copy,
modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.

The table in `README.md` quotes that notice once, inside a cell, when it points
at `tests/geodtest.c:7`; a quote of the notice stays under the same grant. The
rest of that file is this fork's own description of what it cites, and is
treated as this fork's own below.

## `README.md` and `LICENSE.md` — no licence asserted

These two files are written by this fork. Upstream's MIT grant covers upstream's
work; it does not reach a description this fork wrote about upstream's numbers,
and this repository does not have the standing to grant them on the owner's
behalf. **This repository states no licence for `README.md` and `LICENSE.md`,
and records that here rather than answering it.** The choice belongs to whoever
owns this fork; see `NOTICE.md` § "The one question left open", which covers the
rest of the fork's own files on the same terms.

Note what this is not. It is not a claim that the prose is free for any use, and
it is not a second grant hiding behind the block quoted above. It is the
absence of a decision, recorded honestly so that nobody downstream reads
upstream's MIT line at the top of this file as covering text it was never
offered for.

## What is deliberately not here

* No data was fetched from a third party. There is no Unicode Consortium terms
  question, no supplemental fixture licence, and no separate grant of any kind
  in this directory.
* No generated table, no expanded corpus and no additional cases. The 240
  numbers are the whole of upstream's table; the corners are in `tests/`.