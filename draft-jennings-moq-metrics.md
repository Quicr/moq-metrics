%%%
title = "Metrics over MOQT"
abbrev = "moqt-metrics"
ipr= "trust200902"
area = "art"
workgroup = ""
keyword = ["metrics","moq"]

[seriesInfo]
status = "informational"
name = "Internet-Draft"
value = "draft-jennings-moq-metrics"
stream = "IETF"

[[author]]
initials="C."
surname="Jennings"
fullname="Cullen Jennings"
organization = "Cisco"
[author.address]
email = "fluffy@iii.ca"
[author.address.postal]
country = "Canada"

%%%

.# Abstract

Many systems produce significant volumes of metrics which either are 
not all needed at the same time for consumption by collection/aggregation
endpoints or will compete for bandwidth with the primary application, thus 
exacerbating congestion conditions especially in low-bandwidth networks. 
Delivering these over architectures enabled by publish/subscribe transport like 
Media Over QUIC Transport (MOQT) [@!I-D.ietf-moq-transport], 
allows metrics data to be prioritized within the congestion context of the 
primary application as well as enabling local 
nodes to cache the metric value to be later retrieved via new subscriptions. 

{mainmatter}

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
data to sent to the metrics collectors or aggregators, all at the
same time. Instead, metrics that are frequently collected and reported
can be cached in local nodes and a new subscription can fetch only
the metrics that are needed. This allows for a "just in time" delivery 
of metrics.

This document specifies how to send metrics type 
information over the Media Over QUIC Transport (MOQT).


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

The devices or systems publishing the metrics are referred  to as "Resources" and have 
unique "ResourceID".

Each metric reported by an ```Resource``` has an associated ```timeseries```. A metric's timeseries
is time ordered set of values (observations at points in time) for the corresponding metric. 
Metric names are represented as strings and may contain ASCII letters, digits, underscores, 
and colon. A metric's value can be one of "Gauge" or "Counter". The "Gauge" value type 
represents a scalar  value that always represents the current value being measured. The "Counter" 
value type is a cumulative value that represents a single monotonically increasing value that can 
increase or be reset to zero on restart. The Gauge and Counter can represent either a 64-bit 
floating point value or a 64-bit integer value.

Resources also define zero or more ```Attributes```. Attributes capture the dimensional data to 
identify any given combination of them for the metrics reported by the resource.
Attributes are represented as key-value pairs and represented as strings.

The data model specified in this section is consistent with the "OpenTelemetry
Specification 1.34.0" [@?otel] for metrics when at rest (also known as 
Timeseries model). See section (#moqt-mapping) for streaming model where
MOQT is used for transporting the metric data.

## ResourceID

Each resource that creates metrics has a unique "ResourceID". This is created by
taking the MAC address of the primary network interface in binary,
computing the sha1 hash of it, and truncating to lower 64 bits. Note the
sha1 does not provide any security properties, it is just a hash that is
widely implemented in hardware. If this is not possible, any other
random stable 64 bit identifier may be used. The advantage of us MAC
address is that many other management systems use this address and it
makes it easier to correlate. The disadvantage is that it reveals the
MAC address.

## Time

Time is represented by an integer with number of microseconds since "1
Jan 1972" using NTP Era zero conventions.


# Metrics and MOQT {#moqt-mapping}

This section maps the metrics data model defined in this specification to MOQT Object 
model (as defined in section 2 of [@!I-D.ietf-moq-transport]).  The core idea is, the URLs 
for the MOQT objects are setup such that a subscriber could subscribe to each resource 
reporting metrics separately, and could pick the right metrics level in the subscriptions.

The Track Namespace of ```moq://metrics.moq.arpa/metrics-v1/``` is defined in this 
specification. The track name identifies the resource and the granularity level
for the metrics being published. Thus, a track name can be identified with 
```<resourceID>/<level>``` and the full track name having the following format:

~~~
moq://metrics.moq.arpa/metrics-v1/<resourceID>/<level>
~~~


Following granularity levels are defined in this specification, along
with their associated track names.


1. Emergency     : ```<resourceID>/0```
2. Alert         : ```<resourceId>/1```
3. Critical      : ```<resourceId>/2```
4. Error         : ```<resourceId>/3```
5. Warning       : ```<resourceId>/4```
6. Notice        : ```<resourceId>/5```
7. Informational : ```<resourceId>/6```
8. Debug         : ```<resourceId>/7```

Mapping of metrics and its frequency to the aforementioned levels by  a resource 
are application defined. However, it can be typical of an implementation to 
report metrics that represent aggregation of values over larger time intervals 
or that represent erroneous conditions, to use granularity that is one of 
Emergency, Alert, Critical and Error. Such metrics have characteristics of 
being less frequent and hence consume lesser bandwidth. Metrics that are 
captured more frequently and capture detailed view of system being measured 
typically are reported at granularity level of Warning and above. Such metrics, 
however,  consumes  high bandwidth when published.

The MOQT group ID identifies point in time when a given set of metrics
were captured by the resource. Group ID, thus represents capture 
time as number of milliseconds since "1 Jan 1972" using NTP Era zero conventions 
and truncated to 62 bit integer. The first object, with MOQT object Id of 0, 
captures 2 pieces of information:

1. The capture timestamp as UNIX Epoch time in nanoseconds since 00:00:00 UTC 
on 1 January 1970.  

2. One or more attributes scoped to a given resource identified in the track name.
This field is optional and if omitted, the attribute values correspond to most 
recent object 0 that had any attribute values.

The subsequent objects (ObjectId 1 and so on) each capture metric name and the
corresponding value at the time identified in the object with object ID of 0.
The metric name field is optional and if omitted, the metric name from the
object with same object ID seen in the most recent group is considered.

Below is a conceptual representation of the mapping for the metrics
streaming model to the MOQT object model, for resource with
resourceID of "resource-1" and granularity level of "warning (4)".

~~~ ascii-art
TrackName: resource-1/4
  +--------------------+                   +--------------------+
  | Group(Timestamp-1) |                   | Group(Timestamp-N) |
  +--------------------+                   +--------------------+

    +------------------------+              +------------------------+
    |    Object0 (Capture    |              |    Object0 (Capture    |
    |      Timestamp in      |              |      Timestamp in      |
    |Nanoseconds), Attributes|              |Nanoseconds), Attributes|
    +------------------------+              +------------------------+
    +------------------------+              +------------------------+
    |         Object1        |              |        Object1         |
    |  (Metric Name = Value) |              | (Metric Name = Value)  |
    +------------------------+              +------------------------+
    +------------------------+              +------------------------+
    |         Object2        |              |         Object2        |
    |  (Metric Name = Value) |   * * *      |  (Metric Name = Value) |
    +------------------------+              +------------------------+                                    
               *                                        *	  
               *                                        *
   +------------------------+               +------------------------+
   |        ObjectN         |               |        ObjectN         |
   | (Metric Name = Value)  |               | (Metric Name = Value)  |
   +------------------------+               +------------------------+

~~~

## Examples

Here is an example of Object ID 0 data when represented in JSON format [@?RFC8259].
```
{
  "capture_timestamp": 1720367991,
  "attributes": [ { "location": "us-east-2"}, {"os": "ubuntu20.4" }]
}
```
   

Here is an example of Object ID 1 data showing cpu_usage and cpu_temperature metric 
values represented in JSON format [@?RFC8259].

```
{
  "cpu_usage_percent": 99.1,
  "cpu_temperature": 45.1
}
```


See (#model) for details on data types representations for capture
timestamp, attributes, metric names and values.

{backmatter}

# Acknowledgments

Thanks to TODO for contributions and suggestions to this
specification.

<reference anchor='otel' target='https://opentelemetry.io/docs/specs/otel/metrics/data-model/'>
    <front>
        <title/>
        <author/>
        <date year=""/>
    </front>
</reference>
