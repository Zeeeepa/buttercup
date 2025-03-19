from typing import Iterator, Optional
from redis import Redis


class RedisSet:
    def __init__(self, redis: Redis, set_name: str):
        self.redis = redis
        self.set_name = set_name

    # Returns True if the value was already in the set
    def add(self, value: str) -> bool:
        return self.redis.sadd(self.set_name, value) == 0

    # Returns True if the value was already in the set
    def remove(self, value: str) -> bool:
        return self.redis.srem(self.set_name, value) == 1

    def contains(self, value: str) -> bool:
        return self.redis.sismember(self.set_name, value)

    def __iter__(self) -> Iterator[str]:
        for member in self.redis.smembers(self.set_name):
            yield member.decode("utf-8")

    def __len__(self) -> int:
        return self.redis.scard(self.set_name)


class RedisBoolFlag:
    """
    Functions for working with Redis-backed boolean flags.
    These are flags that can be set to true and never change back to false.
    """

    @staticmethod
    def set_true(redis: Redis, flag_name: str) -> None:
        """
        Set the named flag to true, which is an irreversible operation.

        Args:
            redis: Redis client
            flag_name: Name of the flag to set
        """
        redis.set(flag_name, "1")

    @staticmethod
    def is_true(redis: Redis, flag_name: str) -> bool:
        """
        Check if the named flag is true.

        Args:
            redis: Redis client
            flag_name: Name of the flag to check

        Returns:
            True if the flag has been set to true, False otherwise
        """
        value = redis.get(flag_name)
        return value == b"1"
