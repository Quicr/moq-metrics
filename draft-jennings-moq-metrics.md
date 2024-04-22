
# Abstract

Many system produce significant volumes of metrics which do not need may
not be needed. Transporting these over a publish / subscribe
architecture like MoQ allows local nodes to cache the metric values. If
they values are later needed in a new subscription can fetch only the
value that are needed. This allows for a "just in time" delivery of
metrics and reduces transfer of metrics that are not needed.


# Introduction

Each device that produces metrics publishes the metrics with MoQT. The
time series are put in different tracks and individual objects contain
the values at a given timestamp.

# Data Model

A metric time series consists of series of points in time. At each point
in time there can be several measurements as well as several
attributes. Each measurement has a name and value and optional type of
gauge or counter along with an optional unit.

timestamp: time measurement in metric was made

measurement_name, measurement_value: The value is an integer or float
representing counter or gauge. Can have an optional type
measurement_type that is gauge or value. Can have optional
measurement_unit.

attribute_name, attribute_value (AKA dimension). 


### Device ID

Each device that creates logs has a unique deviceID. This is created by
taking the MAC address of the primary network interface in binary,
computing the sha1 hash of it, and truncating to lower 64 bits. Note the
sha1 does not provide any security priories, it is just a hash that is
widely implemented in hardware. If this is not possible, any other
random stable 64 bit identifier may be used. The advantage of us MAC
address is that many other management systems use this address and it
makes it easier to correlate. The disadvantage is that it reveals the
MAC address.

### Time

Time is represented by an integer with number of microseconds since "1
Jan 1972" using NTP Era zero conventions.

# Mapping to MoQ Objects

At each point in time, on object with just the timestamp is written to
group 0. The object id is the time truncated to 62 bit integer. At the
same time an object with all the attributes is written to group 1 with
the same groupID. Each measurement is written to it's own object and the
groupID is formed by the last 16 bits of the sha1 hash of the metric
name.



# Naming

The Namespace used is "moq://mnetrics.moq.arpa/metrics-v1/"

The Track name used is the binary deviceID 


# Data Encoding

### Group 0 

TBD Binary Encoding of:

### Group 1

### Group N


