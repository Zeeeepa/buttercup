import pytest
from redis import Redis
from buttercup.common.sets import RedisSet, RedisBoolFlag


@pytest.fixture
def redis_client():
    return Redis(host="localhost", port=6379, db=0)


def test_redis_set_add_and_contains(redis_client):
    # Create a RedisSet instance
    redis_set = RedisSet(redis_client, "test_set")

    # Test adding a value
    test_value = "test_value"
    was_present = redis_set.add(test_value)
    assert not was_present  # Should return False since value wasn't already in set

    # Verify the value is in the set
    assert redis_set.contains(test_value)

    # Add same value again
    was_present = redis_set.add(test_value)
    assert was_present  # Should return True since value was already in set

    # Clean up
    redis_client.delete("test_set")


def test_redis_set_remove(redis_client):
    # Create a RedisSet instance
    redis_set = RedisSet(redis_client, "test_set_remove")

    # Add a value
    test_value = "test_value"
    redis_set.add(test_value)

    # Test removing the value
    was_present = redis_set.remove(test_value)
    assert was_present  # Should return True since value was in set

    # Verify value was removed
    assert not redis_set.contains(test_value)

    # Try removing non-existent value
    was_present = redis_set.remove("nonexistent")
    assert not was_present  # Should return False since value wasn't in set

    # Clean up
    redis_client.delete("test_set_remove")


def test_redis_set_iteration_and_length(redis_client):
    # Create a RedisSet instance
    redis_set = RedisSet(redis_client, "test_set_iter")

    # Add some values
    test_values = ["value1", "value2", "value3"]
    for value in test_values:
        redis_set.add(value)

    # Test length
    assert len(redis_set) == len(test_values)

    # Test iteration
    retrieved_values = list(redis_set)
    assert len(retrieved_values) == len(test_values)
    for value in test_values:
        assert value in retrieved_values

    # Clean up
    redis_client.delete("test_set_iter")


def test_redis_bool_flag(redis_client):
    flag_name = "test_bool_flag"

    # Initially the flag should be false
    assert not RedisBoolFlag.is_true(redis_client, flag_name)

    # After setting to true, it should remain true
    RedisBoolFlag.set_true(redis_client, flag_name)
    assert RedisBoolFlag.is_true(redis_client, flag_name)

    # Clear the Redis value (simulate another service restarting Redis)
    redis_client.delete(flag_name)

    # Flag should now be false since we've removed it from Redis
    assert not RedisBoolFlag.is_true(redis_client, flag_name)
