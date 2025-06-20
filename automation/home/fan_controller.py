#!/usr/bin/env python3
"""Modern WAC Smart Fan Controller with Python 3.12+ features."""

import argparse
import json
import logging
import sys
from dataclasses import dataclass
from enum import IntEnum
from pathlib import Path
from typing import Any, Dict, Optional

import requests


class FanSpeed(IntEnum):
    """Valid fan speed levels."""
    MIN = 1
    LOW = 2
    MEDIUM = 3
    HIGH = 4
    VERY_HIGH = 5
    MAX = 6


class FanControlError(Exception):
    """Custom exception for fan control operations."""
    pass


@dataclass(frozen=True)
class FanConfig:
    """Configuration for the fan controller."""
    ip_address: str = "192.168.1.26"
    timeout: int = 3
    
    @property
    def url(self) -> str:
        """Get the fan control URL."""
        return f"http://{self.ip_address}/mf"
    
    @property
    def headers(self) -> Dict[str, str]:
        """Get HTTP headers for requests."""
        return {"Content-Type": "application/x-www-form-urlencoded"}


class FanController:
    """Smart fan controller with modern Python features."""
    
    def __init__(self, config: FanConfig) -> None:
        self.config = config
        self.logger = logging.getLogger(__name__)
    
    def _send_command(self, payload: Dict[str, Any]) -> requests.Response:
        """Send command to the fan and return response."""
        try:
            self.logger.debug("Sending command: %s", payload)
            response = requests.post(
                self.config.url,
                headers=self.config.headers,
                data=json.dumps(payload),
                timeout=self.config.timeout
            )
            response.raise_for_status()
            self.logger.info("Command sent successfully [%d]: %s", 
                           response.status_code, response.text)
            return response
        except requests.RequestException as e:
            self.logger.error("Failed to send command: %s", e)
            raise FanControlError(f"Communication error: {e}") from e
    
    def turn_on(self, speed: int = FanSpeed.MEDIUM) -> None:
        """Turn the fan on with specified speed (1-6)."""
        if not FanSpeed.MIN <= speed <= FanSpeed.MAX:
            raise ValueError(f"Speed must be between {FanSpeed.MIN} and {FanSpeed.MAX}")
        
        self.logger.info("Turning fan on at speed %d", speed)
        self._send_command({"fanOn": True, "fanSpeed": speed})
    
    def turn_off(self) -> None:
        """Turn the fan off."""
        self.logger.info("Turning fan off")
        self._send_command({"fanOn": False})
    
    def light_on(self) -> None:
        """Turn the light on."""
        self.logger.info("Turning light on")
        self._send_command({"lightOn": True})
    
    def light_off(self) -> None:
        """Turn the light off."""
        self.logger.info("Turning light off")
        self._send_command({"lightOn": False})
    
    def get_status(self) -> None:
        """Query the current fan and light status."""
        self.logger.info("Querying fan status")
        self._send_command({"queryDynamicShadowData": 1})


def setup_logging(verbose: bool = False) -> None:
    """Configure logging for the application."""
    level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(
        level=level,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        handlers=[
            logging.StreamHandler(sys.stdout),
            logging.FileHandler(Path.home() / ".fan_controller.log")
        ]
    )


def create_parser() -> argparse.ArgumentParser:
    """Create and configure the argument parser."""
    parser = argparse.ArgumentParser(
        description="Control your WAC Smart Fan",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=f"""
Fan speed levels:
  {FanSpeed.MIN} - Minimum
  {FanSpeed.LOW} - Low  
  {FanSpeed.MEDIUM} - Medium (default)
  {FanSpeed.HIGH} - High
  {FanSpeed.VERY_HIGH} - Very High
  {FanSpeed.MAX} - Maximum
"""
    )
    
    # Mutually exclusive group for main actions
    action_group = parser.add_mutually_exclusive_group(required=True)
    action_group.add_argument(
        "--fan-on", 
        type=int, 
        metavar="SPEED",
        choices=range(FanSpeed.MIN, FanSpeed.MAX + 1),
        help=f"Turn fan on with speed ({FanSpeed.MIN}-{FanSpeed.MAX})"
    )
    action_group.add_argument(
        "--fan-off", 
        action="store_true", 
        help="Turn fan off"
    )
    action_group.add_argument(
        "--light-on", 
        action="store_true", 
        help="Turn light on"
    )
    action_group.add_argument(
        "--light-off", 
        action="store_true", 
        help="Turn light off"
    )
    action_group.add_argument(
        "--status", 
        action="store_true", 
        help="Get current fan/light state"
    )
    
    # Optional configuration
    parser.add_argument(
        "--ip", 
        default="192.168.1.26",
        help="Fan IP address (default: %(default)s)"
    )
    parser.add_argument(
        "--timeout", 
        type=int, 
        default=3,
        help="Request timeout in seconds (default: %(default)s)"
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Enable verbose logging"
    )
    
    return parser


def main() -> None:
    """Main entry point for the fan controller."""
    parser = create_parser()
    args = parser.parse_args()
    
    # Setup logging first
    setup_logging(args.verbose)
    logger = logging.getLogger(__name__)
    
    try:
        # Create configuration and controller
        config = FanConfig(ip_address=args.ip, timeout=args.timeout)
        controller = FanController(config)
        
        # Use pattern matching for cleaner action handling (Python 3.10+)
        match args:
            case _ if args.fan_on is not None:
                controller.turn_on(args.fan_on)
            case _ if args.fan_off:
                controller.turn_off()
            case _ if args.light_on:
                controller.light_on()
            case _ if args.light_off:
                controller.light_off()
            case _ if args.status:
                controller.get_status()
    
    except (FanControlError, ValueError) as e:
        logger.error("Operation failed: %s", e)
        sys.exit(1)
    except KeyboardInterrupt:
        logger.info("Operation cancelled by user")
        sys.exit(130)
    except Exception as e:
        logger.error("Unexpected error: %s", e)
        sys.exit(1)


if __name__ == "__main__":
    main()
