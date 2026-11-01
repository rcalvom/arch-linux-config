"""Temporary compatibility fix for IOT KLAP v2 TP-Link devices.

Remove this component once python-kasa includes upstream PR #1692 or equivalent.
"""

from __future__ import annotations

import logging

import kasa.device_factory
import kasa.discover
from kasa.deviceconfig import DeviceEncryptionType, DeviceFamily
from kasa.protocols import IotProtocol
from kasa.transports import KlapTransportV2
from homeassistant.core import HomeAssistant
from homeassistant.helpers.typing import ConfigType

_LOGGER = logging.getLogger(__name__)
_ORIGINAL_GET_PROTOCOL = kasa.device_factory.get_protocol


def _get_protocol(config, *, strict: bool = False):
    """Select KLAP v2 for IOT bulbs and switches that advertise login v2."""
    connection_type = config.connection_type
    if (
        connection_type.device_family
        in {
            DeviceFamily.IotSmartPlugSwitch,
            DeviceFamily.IotSmartBulb,
        }
        and connection_type.encryption_type is DeviceEncryptionType.Klap
        and (connection_type.login_version or 1) >= 2
    ):
        _LOGGER.warning("Selecting KLAP v2 transport for an IOT device with login v2")
        return IotProtocol(transport=KlapTransportV2(config=config))
    return _ORIGINAL_GET_PROTOCOL(config, strict=strict)


async def async_setup(hass: HomeAssistant, config: ConfigType) -> bool:
    """Install the scoped python-kasa transport selection override."""
    kasa.device_factory.get_protocol = _get_protocol
    kasa.discover.get_protocol = _get_protocol
    _LOGGER.warning(
        "Applied temporary TP-Link IOT KLAP v2 compatibility fix; remove it after "
        "python-kasa upstream PR #1692 or an equivalent release is available"
    )
    return True
