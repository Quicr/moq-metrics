---
title: "Metrics over MOQT"
abbrev: "moqt-metrics"
docname: draft-jennings-moq-metrics-latest
category: info
submissiontype: IETF
ipr: trust200902
area: art
workgroup: ""
keyword:
 - metrics
 - moq

stand_alone: yes
smart_quotes: no
pi: [toc, sortrefs, symrefs]

author:
 -
    ins: C. Jennings
    name: Cullen Jennings
    organization: Cisco
    email: fluffy@iii.ca
    country: Canada
 -
    ins: S. Nandakumar
    name: Suhas Nandakumar
    organization: Cisco
    email: snandaku@cisco.com
    country: USA

normative:
  MOQT: I-D.draft-ietf-moq-transport-22

informative:
  OTEL:
    title: "OpenTelemetry Metrics Data Model"
    target: https://opentelemetry.io/docs/specs/otel/metrics/data-model/
    author:
      org: OpenTelemetry

--- abstract

Many systems produce significant volumes of metrics which either are
not all needed at the same time for consumption by collection/aggregation
endpoints or may also compete for bandwidth with the primary application, thus
exacerbating congestion conditions especially in low-bandwidth networks.
Delivering these over architectures enabled by publish/subscribe transport like
Media Over QUIC Transport (MOQT) {{MOQT}},
allows metrics data to be prioritized within the congestion context of the
primary application as well as enabling local
nodes to cache the metric value to be later retrieved via new subscriptions.

This document specifies how to send metrics type
information over the Media Over QUIC Transport (MOQT).

--- middle

# Introduction

Systems often run into the problem when the network bandwidth
for metrics is shared with the realtime media which impacts the media
quality. This is especially true for realtime systems wherein metrics
compete with bandwidth for media resulting in reduction of the
available peak bandwidth for the primary application and often
cause congestion in low-bandwidth networks. There is a desire to
transport the metrics data at an appropriate priority level over the
same transport as the application media. This allows the
metrics data to take advantage of times when the media bitrate is below
the peak rate while not impacting the peak rate available for media.

Publishing metrics over architectures enabled via MOQT provides
additional benefits of leveraging MOQT Relays as caches to store
metrics in local nodes. This allows limiting the volume of
data sent to the metrics collectors or aggregators. Instead, metrics that
are frequently collected and reported can be cached in local nodes and a
new subscription can fetch only the metrics that are needed. This allows for a
"just in time" delivery of metrics.

This document specifies how to send metrics type
information over the Media Over QUIC Transport (MOQT).


# Conventions and Definitions

{::boilerplate bcp14-tagged}


# Architecture Overview {#arch}

This section describes two deployment models for metrics over MOQT. In
both, resources publish metrics as MOQT tracks (see {{moqt-mapping}}) to a
relay, and metrics collectors subscribe to them via relays. Relays cache
metrics so that collectors can retrieve them later.

## Metrics Sharing a Session with Media {#arch-shared}

In this model, an endpoint such as a realtime conferencing client
publishes its media and its metrics over the same MOQT session, and thus
the same QUIC connection, to its ingress relay. Media and metrics share
the congestion control context of that connection, and MOQT priorities
(see {{priorities}}) determine what is sent when the available bandwidth
is limited. Metrics use the bandwidth left over when the media bitrate is
below the peak, without reducing the peak rate available for media.

At the relay, media and metrics are forwarded to different destinations:
media to the other participants, and metrics to a metrics collector,
possibly through other relays. The relay does not need to treat the two
differently beyond the track names and properties.

~~~ ascii-art
                  one QUIC connection
              (shared congestion control)
+------------+                   +---------+  media  +--------------+
|  Endpoint  |      media        |         |-------->| Participants |
| +--------+ |==================>|         |         +--------------+
| | Media  | |                   |  Relay  |
| +--------+ |      metrics      |         | metrics +--------------+
| |Metrics | |==================>| (cache) |-------->|   Metrics    |
| +--------+ |   (pri 128..240)  |         |         |  Collector   |
+------------+                   +---------+         +--------------+
~~~

When congestion occurs on the endpoint's connection, objects of the
higher granularity metrics levels are the first to be delayed and, with
OBJECT_DELIVERY_TIMEOUT, dropped, while media is unaffected. The relay
continues to cache what it has received, and a collector can retrieve
the metrics for a time window of interest later using FETCH
(see {{retrieval}}).

## Metrics as the Primary Data {#arch-dedicated}

In this model, the endpoints, such as servers, network devices or sensors,
send metrics as their main data over MOQT. Each endpoint publishes its
metrics tracks to a relay, which may aggregate many endpoints, and one or
more metrics collectors subscribe to them.

~~~ ascii-art
+------------+
| Endpoint 1 |--metrics--+
+------------+           |
                         v
+------------+      +---------+       +---------+     +-----------+
| Endpoint 2 |----->|  Relay  |------>|  Relay  |---->|  Metrics  |
+------------+      | (cache) |       | (cache) |     | Collector |
                    +---------+       +---------+     +-----------+
+------------+           ^                 |
| Endpoint N |--metrics--+                 |          +-----------+
+------------+                             +--------->| Dashboard |
                                                      +-----------+
~~~

Collectors discover endpoints using SUBSCRIBE_NAMESPACE and subscribe to
the levels of interest of each endpoint (see {{discovery}}). Endpoints can publish all granularity levels to the
nearby relay while only the lower granularity levels flow continuously to
the collector. The higher granularity levels remain in the relay cache
and are fetched only when needed, which limits the bandwidth used between
the relay and the collector. Multiple consumers, such as a collector and
a dashboard, can subscribe to the same tracks through relays without the
endpoint sending the data more than once.


# Metrics Data Model {#model}

Below picture captures relationship between the entities in the data model.

~~~ ascii-art
+---------------------+
|      Resource       |                  Attribute
|       - ResourceID  |
+---------------------+                 +--------------------+
   |                                    |    Key: String     |
   |                              +---->|   Value: String    |
   |                              |     +--------------------+
   |    +------------------+      |
   +--->|Attributes [1..n] | -----+
   |    +------------------+             +--------------------+
   |                              +----->|Metric Name: String |
   |                              |      +--------------------+
   |    +------------------+      |
   +--> |      Metric      |------+    +--------------------------+
        +------------------+      |    |      TimeSeries 1..n     |
                                  +--->|    [{time, value}, ...]  |
                                       +--------------------------+


~~~

TODO: Define ABNF.

The devices or systems publishing the metrics are referred  to as "Resources" and have an
unique "ResourceID".

Each metric reported by an `Resource` has an associated `timeseries`. A metric's timeseries
is time ordered set of values (observations at points in time) for the corresponding metric.
Metric names are represented as strings and may contain ASCII letters, digits, underscores,
and colon. A metric's value can be one of "Gauge" or "Counter". The "Gauge" value type
represents a scalar  value that always represents the current value being measured. The "Counter"
value type is a cumulative value that represents a single monotonically increasing value that can
increase or be reset to zero on restart. The Gauge and Counter can represent either a 64-bit
floating point value or a 64-bit integer value.

Resources also define zero or more `Attributes`. Attributes capture the dimensional data to
identify any given combination of them for the metrics reported by the resource.
Attributes are represented as key-value pairs and represented as strings.

The data model specified in this section is consistent with the "OpenTelemetry
Specification 1.34.0" {{OTEL}} for metrics when at rest (also known as
Timeseries model). See {{moqt-mapping}} for streaming model where
MOQT is used for transporting the metric data.

## ResourceID {#resourceid}

Each resource that creates metrics has a unique "ResourceID". This is created by
taking the MAC address of the primary network interface in binary,
computing the sha1 hash of it, and truncating to lower 64 bits. Note the
sha1 does not provide any security properties, it is just a hash that is
widely implemented in hardware. If this is not possible, any other
random stable 64 bit identifier may be used. The advantage of us MAC
address is that many other management systems use this address and it
makes it easier to correlate. The disadvantage is that it reveals the
MAC address.

When carried in MOQT names, the ResourceID is encoded as exactly 16
lowercase hexadecimal ASCII characters.


# Metrics and MOQT {#moqt-mapping}

This section maps the metrics data model defined in this specification to
the MOQT Object Data Model ({{Section 2 of MOQT}}). The
core idea is that the names of the MOQT tracks are set up such that a
subscriber can discover and subscribe to each resource reporting metrics
separately, pick the right granularity level, and select individual metrics
using MOQT filters, while relays cache and serve past metric values.

## Track Naming {#naming}

Each resource publishes its metrics under the Track Namespace consisting of
the following three Track Namespace Fields, each encoded as ASCII:

~~~
("metrics.moq.arpa", "v1", <resourceID>)
~~~

The Track Namespace Prefix `("metrics.moq.arpa", "v1")` is common to all
resources, which allows a collector to discover all resources
(see {{discovery}}). Within a resource's namespace the following tracks are
defined:

* One data track per granularity level. The Track Name is a single ASCII
  digit identifying the level (see {{levels}}).

* One catalog track with the Track Name `catalog` (see {{catalog}}).

Using the serialization format in {{Section 8.8 of MOQT}},
the Warning level track of the resource with ResourceID
`8f2c4a1b0e9d7c63` is rendered as:

~~~
metrics.2emoq.2earpa-v1-8f2c4a1b0e9d7c63--4
~~~

## Granularity Levels {#levels}

Following granularity levels are defined in this specification, along
with their associated track names and RECOMMENDED default publisher
priorities (see {{priorities}}).

| Level         | Track Name | Default Publisher Priority |
|:--------------|:----------:|:--------------------------:|
| Emergency     | `0`    | 128                        |
| Alert         | `1`    | 144                        |
| Critical      | `2`    | 160                        |
| Error         | `3`    | 176                        |
| Warning       | `4`    | 192                        |
| Notice        | `5`    | 208                        |
| Informational | `6`    | 224                        |
| Debug         | `7`    | 240                        |

Mapping of metrics and its reporting frequency at the aforementioned levels by
a resource is application defined. However, it can be typical of an implementation to
report metrics that represent aggregation of values over larger time intervals
or that represent erroneous conditions, to use granularity that is one of
Emergency, Alert, Critical and Error. Such metrics have characteristics of
being less frequent and hence consume lesser bandwidth. Metrics that are
captured more frequently and capture detailed view of system being measured
typically are reported at granularity level of Warning and above. Such metrics,
however, consume high bandwidth when published.

## Catalog Track {#catalog}

The catalog track describes the resource and the metrics it publishes.
Each catalog group is one version of the catalog, and its objects mirror
the objects of data groups:

* Object ID 0 carries the catalog header.

* Object ID N, for N > 0, carries the Metric Description of the metric
  with Metric Index N.

The Metric Index of a metric is the Object ID of its Metric Description in
the catalog group, and is also the Object ID that carries the metric's
value in data groups ({{groups}}). It is not encoded in the Metric
Description itself. Metric Indices are unique across all data tracks of
the resource within a catalog version.

The catalog header and metric description are encoded as follows, using
the notation of {{Section 1.3 of !RFC9000}} and the variable-length
integer (vi64) of {{Section 8.1 of MOQT}}.

~~~
Catalog Header {
  Version (vi64),
  Number of Attributes (vi64),
  Attribute (..) ...,
}

Attribute {
  Key Length (vi64),
  Key (..),
  Value Length (vi64),
  Value (..),
}
~~~
{: title="Catalog Header (Object ID 0)"}

* Version: The catalog format version. This document defines version 1.

* Attribute: A resource attribute, where Key and Value are UTF-8 strings.

~~~
Metric Description {
  Metric Type (vi64),
  Value Representation (vi64),
  Subgroup ID (vi64),
  Name Length (vi64),
  Name (..),
  Unit Length (vi64),
  Unit (..),
}
~~~
{: title="Metric Description (Object ID N > 0)"}

A Metric Description is the payload of catalog Object ID N, for N > 0.
A subscriber uses it to interpret the data objects with Object ID N in any
data group that refers to this catalog version: the Name and Metric Type
identify the metric, and the Value Representation determines how the
Metric Value is decoded.

* Metric Type: 0x0 for Gauge, 0x1 for Counter (see {{model}}).

* Value Representation: The encoding of the metric value in data objects
  (see {{groups}}): 0x0 for an unsigned integer, 0x1 for a signed
  integer, 0x2 for a floating point number.

* Subgroup ID: The Subgroup ID carrying the metric in data groups
  (see {{subgroups}}).

* Name: The metric name, in ASCII (see {{model}}).

* Unit: The unit of the value following {{OTEL}} conventions, or empty
  if not specified.

Receivers MUST ignore any bytes following the fields defined in this
document, to allow future extension.

The Group ID of a catalog group is the catalog version number. The first
version has Group ID 1, and each new version increments it by one, so the
reference carried in every data group (see {{groups}}) stays small. The
publisher MUST publish a catalog group before any data group that refers
to it.

Metric Indices are scoped to a catalog version: a new catalog version MAY
assign indices differently. Publishers SHOULD keep indices stable across
versions, which keeps Object ID filters valid (see {{filtering}}) and
allows unchanged metric descriptions to be reused.

Because each metric is described by its own object, a subscriber does not
need the complete catalog before decoding data. It can decode the value
in data Object ID N as soon as it has catalog Object ID N of the referenced
version, and it can retrieve only the descriptions it needs by applying
the same Object ID filter to the catalog track as to the data track.

A subscriber SHOULD subscribe to the catalog track in parallel with the
data tracks, using FILL_PARAMETERS selecting the current group
({{Section 3.5 of MOQT}}), and hold data objects until the referenced
catalog objects are received. Catalog versions rarely change, so
subscribers MAY cache them per Track Namespace and catalog version and
use a cached version without waiting. A subscriber that receives a data
group referring to a catalog version it does not have retrieves it with
FETCH.

The catalog track MUST use subgroup delivery and SHOULD carry the
following Track Properties:

* MAX_CACHE_DURATION no shorter than that of any data track of the
  resource, so that cached data remains interpretable.

* DEFAULT_PUBLISHER_PRIORITY numerically lower than that of any data
  track of the resource, so that catalog objects arrive ahead of the data
  that depends on them.

* No OBJECT_DELIVERY_TIMEOUT.

## Groups and Objects {#groups}

Each group in a data track holds the set of metrics captured by the
resource at one point in time. The Group ID is the capture time in
milliseconds since the UNIX Epoch (00:00:00 UTC on 1 January 1970). This
satisfies the requirement that Group IDs increase with time
({{Section 2.3.1 of MOQT}}) and allows subscribers to
express time ranges directly as Location filters (see {{retrieval}}).

Each group is independently useful: decoding a group requires only the
objects in that group and the catalog version it refers to. Objects
within a group are:

* Object ID 0 is REQUIRED and carries the Capture Info.

* Object ID N, for N > 0, carries the Metric Value of the metric with
  Metric Index N in the referenced catalog version, observed at the
  capture time.

~~~
Capture Info {
  Capture Timestamp Offset (vi64),
  Catalog Version (vi64),
}
~~~
{: title="Capture Info (Object ID 0)"}

* Capture Timestamp Offset: The nanoseconds to add to the Group ID, in
  milliseconds, to obtain the precise capture time. The value is less
  than 1000000.

* Catalog Version: The Group ID of the catalog version used by this
  group. A subscriber that does not have this version holds the group
  and retrieves the version, so that it never interprets values with a
  stale catalog.

The Metric Value is the entire object payload, encoded according to the
Value Representation of the metric:

* Unsigned integer: a vi64.

* Signed integer: a 64-bit two's complement integer in network byte
  order.

* Floating point: an IEEE 754 binary64 value in network byte order.

A resource that does not report a given metric at a capture time simply
omits that object.
A subscriber or relay cannot infer anything from a missing Object ID
({{Section 2.1.2 of MOQT}}); a publisher MAY use the
Prior Object ID Gap Object Property to signal that skipped Object IDs do
not exist.

Resources typically do not capture metrics every millisecond, so Group IDs
in a data track are sparse. The publisher SHOULD include the Prior Group ID
Gap Object Property ({{Section 10.8 of MOQT}}) on the
first object of each subgroup, set to the number of milliseconds since the
previous capture minus one. This allows relays and fetches to know that
the intervening groups will never exist, rather than leaving them in the
unknown state.

Below is a conceptual representation of the MOQT mapping for the Warning
(4) track of a resource.

~~~ ascii-art

Track: ("metrics.moq.arpa","v1",<resourceID>) / "4"

  +----------------------+             +----------------------+
  | Group (capture ms T1)|             | Group (capture ms TN)|
  +----------------------+             +----------------------+
    Subgroup 0                           Subgroup 0
    +------------------------+          +------------------------+
    | Object 0 (Capture      |          | Object 0 (Capture      |
    |   Timestamp, Catalog)  |          |   Timestamp, Catalog)  |
    +------------------------+          +------------------------+
    +------------------------+          +------------------------+
    | Object 1 (value of     |          | Object 1 (value of     |
    |   metric index 1)      |   * * *  |   metric index 1)      |
    +------------------------+          +------------------------+
               *                                    *
               *                                    *
    +------------------------+          +------------------------+
    | Object N (value of     |          | Object N (value of     |
    |   metric index N)      |          |   metric index N)      |
    +------------------------+          +------------------------+

~~~

## Subgroups and Datagrams {#subgroups}

By default, a publisher SHOULD send all objects of a group in a single
subgroup (Subgroup ID 0), which maps to a single stream.

A publisher MAY split the metrics of a group into multiple subgroups, for
example to give a set of metrics a different publisher priority from the
rest of the level, or to avoid head-of-line blocking between unrelated
metrics. The assignment of metrics to subgroups SHOULD be consistent
across groups, so that subscribers can select them using a Subgroup ID
range filter. Since every metric object is independent of the others in
its group, loss of a subgroup does not prevent use of the others; objects
in subgroups other than the one carrying Object ID 0 use the Group ID as
their capture time. They depend on Object ID 0 for the catalog version
and are held until it is received.

For levels where losing a sample is preferable to delaying it, such as
Debug, publishers MAY send objects using the Datagram delivery mode.

## Track Properties {#track-properties}

Publishers SHOULD include the following Track Properties
({{Section 8.4 of MOQT}}) on each data track:

* DEFAULT_PUBLISHER_PRIORITY: see {{priorities}}.

* DEFAULT_PUBLISHER_GROUP_ORDER: Ascending (0x1), so that collectors
  receive samples in capture order. Subscribers interested only in the
  freshest value, such as live dashboards, MAY request Descending group
  order.

* MAX_CACHE_DURATION: the retention time for which relays may serve
  cached samples. Lower granularity levels are typically retained longer
  than higher granularity levels.

* OBJECT_DELIVERY_TIMEOUT: for high granularity levels, a timeout after
  which a stale sample is dropped rather than delivered late.

## Priorities {#priorities}

Metrics are expected to yield to the primary application under
congestion. The publisher SHOULD set the DEFAULT_PUBLISHER_PRIORITY Track
Property of each data track to the value in {{levels}}, or another value
that keeps lower granularity levels ahead of higher granularity levels.
These values are in the lower priority half of the range, behind the
MOQT default of 128 typically used for media, with Emergency at par with
the default.

Subscribers can adjust the relative importance of metrics against other
subscriptions in the session using the SUBSCRIBER_PRIORITY parameter,
which is considered before publisher priority.

## Discovery and Subscription {#discovery}

A collector discovers resources by sending SUBSCRIBE_NAMESPACE with the
Track Namespace Prefix `("metrics.moq.arpa", "v1")`. The relay responds
with a NAMESPACE message for each resource namespace, and NAMESPACE_DONE
when a resource stops publishing.

For each discovered resource, the collector subscribes by name to the
catalog track and to the data tracks of the levels it wants to receive
continuously, for example levels 0 to 3. Resources that start publishing
later are learned from subsequent NAMESPACE messages. Tracks of other
levels are not subscribed to and remain available from the relay cache
via FETCH (see {{retrieval}}).

## Filtering {#filtering}

MOQT Range Filters ({{Section 3.3.2 of MOQT}}) carried
in SUBSCRIBE, FETCH or FILL_PARAMETERS allow a collector to further reduce
the data delivered within a track:

* An Object ID range filter selects specific metrics by Metric Index.
  The filter SHOULD include Object ID 0. For example, ranges `[0, 0]` and
  `[3, 5]` deliver Object 0 and the metrics with indices 3 to 5. The same
  filter applied to the catalog track delivers only the catalog header
  and the descriptions of those metrics. A subscriber updates its filters
  when a new catalog version assigns indices differently.

* A Subgroup ID or Publisher Priority range filter selects the metrics
  that the publisher consistently places in particular subgroups
  (see {{subgroups}}).

* An Object Property range filter selects individual samples based on
  application-defined Object Properties. For example, an application can
  mark samples that cross a configured threshold with an Object Property
  from the application-specific range, so that a collector subscribed to
  a high granularity level receives only those samples. Such properties
  are outside the scope of this document.

Range Filters are only available when the relay advertises a non-zero
MAX_FILTER_RANGES. Collectors therefore treat filtering as an
optimization and MUST be able to process unfiltered tracks.

## Retrieval of Past Metrics {#retrieval}

Since Group IDs are capture times in milliseconds, a time range of
metrics corresponds directly to a range of Locations:

* A collector retrieves past samples for a time window `[T1, T2]` by
  sending FETCH with a Location filter from {T1, 0} to {T2, max}. The
  request is served from the relay cache, subject to MAX_CACHE_DURATION.

* A collector that wants recent history followed by live samples sends a
  SUBSCRIBE with a Location filter starting at the Next Object, together
  with FILL_PARAMETERS whose Location filter selects the starting point
  of the history. The relay delivers the history on a fill fetch stream
  and live samples on the subscription, without gaps or duplicates
  ({{Section 3.4 of MOQT}}).

* A collector that only needs live samples subscribes with a Location
  filter starting at the Next Group.

This enables the "just in time" collection model: resources publish all
levels to a nearby relay, while collectors subscribe to the low
granularity levels and fetch the high granularity levels for the time
windows of interest, for example around an alert.

## Examples

The following examples show decoded object payloads.

| Object | Structure          | Content                                       |
|:------:|:-------------------|:----------------------------------------------|
| 0      | Catalog Header     | Version 1; location = us-east-2, os = ubuntu20.4 |
| 1      | Metric Description | cpu_usage_percentage; Gauge; unsigned; unit % |
| 2      | Metric Description | cpu_temperature; Gauge; floating point; unit Cel |
{: title="Catalog track, Group 1"}

| Object | Structure    | Content                                     |
|:------:|:-------------|:--------------------------------------------|
| 0      | Capture Info | Offset 123456 ns; Catalog Version 1 |
| 1      | Metric Value | 99 (cpu_usage_percentage)                   |
| 2      | Metric Value | 45.1 (cpu_temperature)                      |
{: title="Warning track, Group 1720367991000"}

One second later, only cpu_temperature is reported. Object 0 carries
Prior Group ID Gap = 999, as Group IDs 1720367991001 to 1720367991999
will never exist.

| Object | Structure    | Content                                   |
|:------:|:-------------|:------------------------------------------|
| 0      | Capture Info | Offset 4211 ns; Catalog Version 1 |
| 2      | Metric Value | 44.8 (cpu_temperature)                    |
{: title="Warning track, Group 1720367992000"}

The Capture Info of Group 1720367991000 is encoded in 4 bytes:

~~~
c1 e2 40   Capture Timestamp Offset = 123456 (vi64)
01         Catalog Version = 1 (vi64)
~~~

# Use with MSF {#msf}

An MOQT Streaming Format (MSF) {{?MSF=I-D.ietf-moq-msf}} catalog can
direct a client to publish metrics using a `publishTracks` entry with a
`packaging` of `"moqmetrics"` and a `role` of `"metrics"`. In such an
entry:

* `namespace` is the Track Namespace of {{naming}} rendered using
  {{Section 8.8 of MOQT}}, with `%resourceId%` as a placeholder for the
  client's ResourceID: `metrics.2emoq.2earpa-v1-%resourceId%`.

* `name` is the data track for a granularity level ({{levels}}). A
  catalog can include one entry per level it wants the client to
  publish.

A client publishing any data track in this way also publishes the
catalog track ({{catalog}}) in the same namespace. The `connectionUri`
and `token` of the entry apply to the catalog track as well.

# IANA Considerations {#iana}

This document has no IANA actions.

# Security Considerations

The ResourceID, when derived from a MAC address, can reveal that address
(see {{resourceid}}). Resource attributes and metric values are
carried in object payloads and can be protected end to end; Track Names,
Group IDs (capture times) and Track Properties are visible to relays. The
security considerations of {{MOQT}} apply.

--- back

# Changes from the ietf122 Version

* Aligned with draft-ietf-moq-transport-22.

* Track Namespace is now the tuple ("metrics.moq.arpa", "v1",
  resourceID); the string form uses the MOQT serialization format
  instead of a moq:// URL.

* Group ID is the capture time in milliseconds since the UNIX Epoch as a
  full 64-bit value.

* Groups are self-contained. Attributes and metric names moved to a
  catalog track with one object per metric, and each data group refers
  to the catalog version that maps its Object IDs to metrics, which
  removes the dependency on previous groups.

* Added the use of Prior Group ID Gap, subgroups and datagrams, Track
  Properties for priority, group order, caching and delivery timeouts,
  SUBSCRIBE_NAMESPACE for discovery, range filters for metric selection,
  and FETCH and fill for time range retrieval.

* Specified the catalog format and added use with MSF.

* Object payloads use a binary encoding following the MOQT notation.

* Added an Architecture Overview describing metrics sharing a session
  with media, and metrics as the primary data.

# Acknowledgments
{:numbered="false"}

Thanks to TODO for contributions and suggestions to this
specification.
