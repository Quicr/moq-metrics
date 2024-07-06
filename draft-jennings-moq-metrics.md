
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

# Metrics Data Model

Each metric reported by an endpoint has one or more timeseries. A metric timeseries 
consists of series of points in time. At each point in time there can be several 
```DataPoints``` containing several measurements as well as attributes. Each measurement has 
a name and value, an optional ```ValueType```.

Below picture captures relationship between the entities in the data model.
~~~~~
                                          Attribute
                                        +--------------------------+
                                        | Key: String              |
                             +--------->|                          |
  Datapoint                  |          | Value: String            |
+--------------------------+ |          +--------------------------+
|                          | |
| Attributes[1..n]  -------+-+
|                          |
| Measurements[1..n]-------+-+           
|                          | |          Measurement
+--------------------------+ |          +--------------------------+
                             |          | Name: String             |
                             +--------->| Value: ValueType         |
                                        |            |             |
                                        +------------+-------------+
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


At each point in time, on object with just the timestamp is written to
group 0. The object id is the time truncated to 62 bit integer. At the
same time an object with all the attributes is written to group 1 with
the same groupID. Each measurement is written to it's own object and the
groupID is formed by the last 16 bits of the sha1 hash of the metric
name.

Each group is identified by metrics captture time as integer with number 
of milliseconds since "1 Jan 1972" using NTP Era :zero conventions. 

The first object with Id 0 encoded the timestamp of capturing the datapoint 
in a time series and Object Id 1 identifies the attributes defined as 
"key-value" pairs and individual  measurements themselves are captured 
with the consecutive object Ids starting from ObjectId 2.
 
Below captures an example of mapping metrics :

# Naming

The Namespace used is "moq://metrics.moq.arpa/metrics-v1/"

Following tracks are defined per reporting end-point. Each end-point 
is identified by its device Id as defined in XXX. 

## Metric Summary Reporting 

The Track name defined as "<deviceID>/summary

## Detailed Metrics Reporting

The Track name defined as "<deviceID>/detailed
 

# Data Encoding

### Group 0 

TBD Binary Encoding of:

### Group 1

### Group N

