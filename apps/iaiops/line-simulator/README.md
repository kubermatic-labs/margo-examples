# OEE line simulator

A Modbus TCP production line for the iaiops example. It serves the holding registers of the
iaiops demo line and replays a compressed shift forever.

| Register | Meaning                                              |
| :------- | :--------------------------------------------------- |
| 0        | Run state: 2 running, 0 stopped, 1 idle, 3 fault     |
| 10       | Production counter, advancing while running          |
| 11       | Good-parts counter, about one part in 25 is scrapped |

`simulate_line.py` is unchanged from `demo/oee-line/` in
github.com/industrial-aiops/industrial-aiops at v0.28.0 (commit
`6ca87c9791d358fa7c1c6b1082db4c4140c379ae`), MIT licensed, see `LICENSE.iaiops`. `line.py` serves
its registers and drives them in a loop with counters that keep counting across shifts.

Modbus has no authentication. The chart keeps the simulator inside the cluster, behind a
ClusterIP Service.
