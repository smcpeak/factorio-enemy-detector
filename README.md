# Enemy Detector

Enemy Detector is a mod for [Factorio](https://wiki.factorio.com/).

It provides a combinator that outputs a signal that is the count of all
enemy units within the detection range of a directly adjacent radar.

Simply place it next to a radar (with no gap) and read the "E" signal.

## State of work

This seems to work properly in preliminary testing, but I haven't yet
used it in a real game so I don't consider it "done".

## Balance

In my opinion, base game radars should provide this information already,
so I have set the cost of the combinator entity and its associated
research as minimal.

TODO: Research is not actually implemented.

The combinator returns a count of enemies that precisely reflects what
is within the continuous coverage range of the adjacent radar, thus not
providing any new information.

## Performance considerations

It takes about 100 us to do one scan of a 7x7 chunk region (a chunk is
32x32 tiles), which is the size of a normal-quality radar's coverage in
the base game.  This multiplies across all of the combinators.

To limit the performance impact, the default scanning period is once
every second (60 ticks).  If you create a lot of combinators it may be
necessary to decrease the scanning frequency, since they all scan at the
same time.

Combinators that have their output signals disabled or whose radar is
absent or unpowered do not perform scans, so those provide additional
options for throttling the scan rate.

## Related mods

[radar-signals](https://mods.factorio.com/mod/radar-signals), which I
partly based my implementation on, is the most similar.  The problem
with that mod is you have to configure the combinator in advance with
the types of enemies to detect, whereas I want just one number for the
total of all of them, without having to know in advance what I am
looking for.  (The enemy I want to detect may not have a signal,
and I don't want to look because I haven't finished Space Age and do
not want spoilers!)

[Biter Detector Sentinel Combinator](https://mods.factorio.com/mod/Biter_Detector_Sentinel_Combinator)
has simple functionality, but it scans independently of any radar (which
is a balance issue), and has not been updated for Factorio 2.0 yet.

[Factor-I/O](https://mods.factorio.com/mod/FactorIO) has enemy
sensing capability but also has not been updated for Factorio 2.0 so I
didn't look closely at it.
