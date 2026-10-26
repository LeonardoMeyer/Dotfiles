#!/usr/bin/python

import asyncio
import re
import sys
from contextlib import asynccontextmanager

import pyprland.ipc as ipc
from pyprland.adapters import hyprland as hypr_adapter
from pyprland.adapters import notifier
from pyprland.models import PyprError

_open_connection = ipc.hyprctl_connection


@asynccontextmanager
async def hyprctl_connection(logger):
    try:
        async with _open_connection(logger) as streams:
            yield streams
    except (PyprError, FileNotFoundError):
        raise
    except ConnectionResetError:
        raise
    except OSError as e:  # broken pipe etc while hyprland is busy
        raise ConnectionResetError(str(e)) from e


ipc.hyprctl_connection = hyprctl_connection
hypr_adapter.hyprctl_connection = hyprctl_connection

# socket can stall a few seconds on plugin load
ipc.IPC_MAX_RETRIES = 8


def _never_fail(method):
    async def wrapper(self, *args, log, **kwargs):
        try:
            return await method(self, *args, log=log, **kwargs)
        except Exception as e:  # pylint: disable=W0718
            log.warning("notification dropped: %s", e)
            return None

    return wrapper


for _name in ("notify", "notify_info", "notify_error"):
    setattr(notifier.HyprlandNotifier, _name, _never_fail(getattr(notifier.HyprlandNotifier, _name)))

from pyprland.command import main  # noqa: E402

if __name__ == "__main__":
    sys.argv[0] = re.sub(r"(-script\.pyw|\.exe)?$", "", sys.argv[0])
    sys.exit(main())
