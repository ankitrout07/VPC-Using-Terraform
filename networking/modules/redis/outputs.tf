output "redis_hostname" {
  description = "The hostname of the Redis instance"
  value       = azurerm_redis_cache.redis.hostname
}

output "redis_primary_access_key" {
  description = "The primary access key for the Redis instance"
  value       = azurerm_redis_cache.redis.primary_access_key
  sensitive   = true
}

output "redis_port" {
  description = "The port of the Redis instance"
  value       = azurerm_redis_cache.redis.ssl_port
}
