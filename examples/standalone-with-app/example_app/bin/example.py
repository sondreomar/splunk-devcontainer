import hashlib
import logging
import random
import time

logging.basicConfig(
    filename="/tmp/example.log",
    format="%(asctime)s.%(msecs)03d [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
    level=logging.INFO,
)

single_line = "single {n}"
multi_line = "multi-1 {n}\nmulti-2 {n}"
long_event = "long {n} " + (hashlib.sha512(single_line.encode()).hexdigest() * 128) + " eol {n}"

events = random.choices(
    [single_line, multi_line, long_event],
    weights=[8, 1, 1],
    k=10,
)

for i, event in enumerate(events):
    logging.info(event.format(n=f"{time.time()}:{i}"))
