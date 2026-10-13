"""A production line that runs forever, for the iaiops example.

Serves the Modbus TCP registers of the iaiops demo line (simulate_line.py, unchanged from
industrial-aiops v0.28.0) and replays its compressed shift in a loop: running, minor stops, an
idle period, a long fault. The upstream driver starts both counters from zero on every run, which
iaiops would rightly read as a counter reset, so this driver keeps counting across shifts.

  python line.py --port 5020 --bind 0.0.0.0 --shift-seconds 300
"""

from __future__ import annotations

import argparse
import signal
import sys
import threading
import time

# Imported here, before the driver thread starts: pymodbus imported from two threads at once
# deadlocks on its module locks.
import pymodbus.datastore  # noqa: F401 - used by line.serve
import pymodbus.server  # noqa: F401 - used by line.serve
from pymodbus.client import ModbusTcpClient

import simulate_line as line


def drive_forever(port: int, shift_seconds: float) -> None:
    """Write run state and counters over Modbus, as the PLC program would."""
    client = ModbusTcpClient("127.0.0.1", port=port, timeout=1)
    counter = good = 0
    last = ""
    while True:
        steps = line.script(shift_seconds)
        started = time.monotonic()
        index = 0
        while (elapsed := time.monotonic() - started) < shift_seconds:
            while index + 1 < len(steps) and steps[index + 1][0] <= elapsed:
                index += 1
            _, state, label = steps[index]
            if label != last:
                print(f"[line] t={elapsed:6.1f}s  {label}", flush=True)
                last = label
            if state == line.RUNNING:
                counter += 1
                if counter % line.REJECT_EVERY:
                    good += 1
            try:
                if not client.connected:
                    client.connect()
                client.write_register(address=line.RUN_STATE_ADDR, value=state, device_id=1)
                client.write_register(address=line.COUNTER_ADDR, value=counter % 65535, device_id=1)
                client.write_register(address=line.GOOD_COUNTER_ADDR, value=good % 65535, device_id=1)
            except Exception:  # noqa: BLE001 - the server may not be up yet
                pass
            time.sleep(0.1)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--port", type=int, default=5020)
    ap.add_argument(
        "--bind",
        default="127.0.0.1",
        help="Server bind address. Modbus has no authentication: expose it on a lab network only.",
    )
    ap.add_argument("--shift-seconds", type=float, default=300.0, help="Length of one simulated shift.")
    args = ap.parse_args()

    # PID 1 in a container gets no default SIGTERM handling.
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    threading.Thread(target=drive_forever, args=(args.port, args.shift_seconds), daemon=True).start()
    print(f"[line] Modbus TCP on {args.bind}:{args.port}, shift of {args.shift_seconds:.0f}s", flush=True)
    line.serve(args.port, args.bind)


if __name__ == "__main__":
    main()
