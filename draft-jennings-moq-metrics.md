
# Abstract

Many systems produce significant volumes of metrics which may not be 
all be needed at the same for consumption by collection/aggregation endpoints.
Transporting these over a publish / subscribe  architecture like MoQ allows 
local nodes to cache the metric values. If  any values are later needed, 
a new subscription can fetch only the  value that are needed. This allows 
for a "just in time" delivery of  metrics and reduces transfer of metrics that 
may not be all needed.

# Introduction 

Many systems produce significant volumes of metrics that often cause congestion with 
the primary application in low-bandwidth networks. During congestion or when the 
network is unavailable, metrics can be lost. When considering that the application 
producing metrics may have congestion, network outage, or be abruptly closed, 
sending metrics near real-time is preferred. The challenge with sending metrics 
near real-time is that metrics can cause network congestion for the application 
resulting in both the application under performing and failing to prioritize metrics 
produced under these conditions. This document defines how metrics are produced and 
consumed using Media over Quic Transport (MOQT) to overcome metric caused congestion
with the ability to prioritize both metrics and application data.


Each device that produces metrics publishes the metrics with MOQT. The
time series are put in different tracks and individual objects contain
the values at a given timestamp.

# Idea

~~~~

                          .-------------.
                       ,-'               '-.
                      /      Analytics      \
                     (         Node          )
                        '-.             ,-'
                           \-----------'
                                 ^
                 Pub Track:      | 
              /device1/summary   |
                                 |
                             .-------. 
                          ,-'         '-. 
                         ;  Local Relay  :
                         :    (Cache)    ;
                           '-.       ,-'
                              \-----'
                                ^  ^
             Pub Track:         |  |         Pub Track:
          /device1/summary      |  |     /device1/detailed
                             +--+  +-+
                             |       |
                   +-----------------+--------+
                   |         Device1          |
                   +--------------------------+

~~~~

~~~~
                            .-------------.
                        ,-'               '-.
                       /      Analytics      \
                      (         Node          )--+
                         '-.             ,-'     |
                            \-----------'        |
                                  ^              |
                                  |              |
              Pub Track:          |              |         Sub Track:
          /device1/detailed       |              |     /device1/detailed
               from cache         |              |          {filter}
                                  |              |
                              .-------.          |
                           ,-'         '-.       |
                          ;  Local Relay  :      |
                          :    (Cache)    ;<-----+
                            '-.       ,-'
                               \-----'
                                 ^  ^
              Pub Track:         |  |         Pub Track:
           /device1/summary      |  |     /device1/detailed
                              +--+  +-+
                              |       |
                    +-----------------+--------+
                    |         Device1          |
                    +--------------------------+

~~~~

# Metrics Data Model

Each metric reported by an endpoint has one or more timeseries. A metric timeseries 
consists of series of points in time. At each point in time there can be several 
```DataPoints``` containing several measurements as well as attributes. Each measurement has 
a name and value, an optional ```ValueType```.

Below picture captures relationship between the entities in the data model.
~~~~~
                                          Attribute
                                        +-----------------+
                                        | Key: String     |
                             +--------->|                 |
  Datapoint                  |          | Value: String   |
+--------------------------+ |          +-----------------+
|                          | |
| Attributes[1..n]  -------+-+
|                          |
| Measurements[1..n]-------+-+           
|                          | |          Measurement
+--------------------------+ |          +------------------+
                             |          | Name: String     |
                             +--------->| Value: ValueType |
                                        |            |     |
                                        +------------+-----+
                                                     |
                                                     v
                                        +------------------------+
                                        | Oneof(Guage, Counter)  |
                                        +------------------------+
~~~~~

Measurement names are represented as strings and may contain ASCII letters, digits, 
underscores, and colon. TODO: Define ABNF.

A measurement's value can be one "Gauge" or "Counter". The "Gauge" value type represents a 
type of a scalar metric/sampled value  that always represents the current value at the time 
of measurement. The "Counter" value type for a measurement is a cumulative metric that 
represents a single monotonically increasing value that can increase or be reset to zero 
on restart. The Gauge and Counter can represent either a 64bit floating point value 
or a 64bit integer value.


Attributes define the dimensional data model to identify any given combination of them
for the same measurement. Attributes are typically used for efficient indexing and
querying purposes.

Each datapoint has associated `timestamp` that identifies the time when the measurement in 
metric was made.

## Device ID

Each device that creates metrics has a unique "Device ID". This is created by
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


# Metrics and MOQT Data Model

This section maps the metrics data model defined in this specification to MOQT Object 
model (as defined in section XXX).

~~~~
+--------------------+                           +--------------------+
| Group(Timestamp-1) |                           | Group(Timestamp-N) |
+--------------------+                           +--------------------+
       +------------------------+                      +------------------------+
       |    Object0 (Capture    |                      |    Object0 (Capture    |
       |      Timestamp in      |                      |      Timestamp in      |
       |      Nanoseconds)      |                      |      Nanoseconds)      |
       +------------------------+                      +------------------------+
       +------------------------+                      +------------------------+
       |  Object1 (Datapoint)   |                      |  Object1 (Datapoint)   |
       +------------------------+                      +------------------------+
       +------------------------+                      +------------------------+
       |  Object2 (Datapoint)   |                      |  Object2 (Datapoint)   |
       +------------------------+                      +------------------------+
                  *                                               *
                  *                                               *
       +------------------------+                      +------------------------+
       |  ObjectN (Datapoint)   |                      |  ObjectN (Datapoint)   |
       +------------------------+                      +------------------------+
~~~~       

At each point in time, on object with just the timestamp is written to
group 0. The object id is the time truncated to 62 bit integer. At the
same time an object with all the attributes is written to group 1 with
the same groupID. Each measurement is written to it's own object and the
groupID is formed by the last 16 bits of the sha1 hash of the metric
name.

The MOQT GroupId identifies point in time when a given set of measurements
were captured. GroupId, thus is by metrics capture time with number 
of milliseconds since "1 Jan 1972" using NTP Era :zero conventions and 
truncated to 62 bit integer.

The first object, with ObjectId of 0, captures the Value is UNIX Epoch time in 
nanoseconds since 00:00:00 UTC on 1 January 1970. This time represents the 
time at which a given set of measurements are collected.

The subsequent objects (ObjectId 1 and so on) capture individual DataPoints 
corresponding to the measurements being collected at the time identified
in ObjectId 0.

## MOQT TrackNamespace and Track Name

The Track Namespace ```moq://metrics.moq.arpa/metrics-v1/``` is used for metrics reported 
over MOQT as defined in this specifiction.

Following TrackNames are defined per reporting end-point. Each end-point 
is identified by its device Id as defined in XXX. 

### Metric Summary Reporting 

TrackName ```"<deviceID>/summary``` identifies metrics/measurements that are
reported over a long interval and typically correspond to aggregated or summary
view of things being measured. The Groups and Objects within the summary track 
are less frequent and consume less bandwidth.


### Detailed Metrics Reporting

TrackName  ```<deviceID>/detailed``` identifies metrics that represent 
granular and a detailed view of system being measured. Such metrics are
captured at frequent intervals and when reported shall consume much 
higher bandwidth than the summary metrics. 

