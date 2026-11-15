"""
CropNet AI — Local Ollama Runtime Adapter.

Provides a modular, secure interface to local Ollama running Qwen3:8B.
Strictly local: never exposes Ollama externally; only internal backend
services may communicate with this client.
"""
import logging
import time
from typing import Dict, Any, List, Optional
import httpx

from cropnet.services.api.app.core.config import settings

logger = logging.getLogger(__name__)


class OllamaClient:
    """
    Adapter for communicating with the local Ollama daemon or hosted Groq Cloud API.
    """

    def __init__(
        self,
        base_url: Optional[str] = None,
        default_model: Optional[str] = None,
        timeout_seconds: Optional[int] = None,
        provider: Optional[str] = None,
        groq_api_key: Optional[str] = None,
    ):
        self.provider = (provider or settings.LLM_PROVIDER or "ollama").strip().lower()
        self.groq_api_key = groq_api_key if groq_api_key is not None else settings.GROQ_API_KEY
        if self.provider == "groq":
            self.base_url = (base_url or settings.GROQ_BASE_URL).rstrip("/")
            self.default_model = default_model or settings.GROQ_MODEL
            self.timeout_seconds = timeout_seconds or settings.GROQ_TIMEOUT_SECONDS
        else:
            self.base_url = (base_url or settings.OLLAMA_BASE_URL).rstrip("/")
            self.default_model = default_model or settings.OLLAMA_MODEL
            self.timeout_seconds = timeout_seconds or settings.OLLAMA_TIMEOUT_SECONDS

    def _groq_headers(self) -> Dict[str, str]:
        return {
            "Authorization": f"Bearer {self.groq_api_key or ''}",
            "Content-Type": "application/json",
        }

    def is_available(self) -> bool:
        """
        Check if the configured LLM runtime (Ollama or Groq) is responsive.
        """
        if self.provider == "groq":
            if not self.groq_api_key:
                return False
            try:
                with httpx.Client(timeout=3.0) as client:
                    resp = client.get(f"{self.base_url}/models", headers=self._groq_headers())
                    return resp.status_code == 200
            except Exception as e:
                logger.debug("Groq API not reachable: %s", e)
                return False
        if not settings.OLLAMA_ENABLED:
            return False
        try:
            with httpx.Client(timeout=3.0) as client:
                resp = client.get(f"{self.base_url}/api/tags")
                return resp.status_code == 200
        except Exception as e:
            logger.debug(f"Ollama server not reachable at {self.base_url}: {e}")
            return False

    def is_model_available(self, model_name: Optional[str] = None) -> bool:
        """
        Verify that the requested model is available in Ollama or Groq.
        """
        target = model_name or self.default_model
        if self.provider == "groq":
            if not self.groq_api_key:
                return False
            try:
                with httpx.Client(timeout=3.0) as client:
                    resp = client.get(f"{self.base_url}/models", headers=self._groq_headers())
                    if resp.status_code == 200:
                        models = [m.get("id", "") for m in resp.json().get("data", [])]
                        return target in models
                    return False
            except Exception as e:
                logger.debug("Error checking model %s in Groq: %s", target, e)
                return False
        try:
            with httpx.Client(timeout=3.0) as client:
                resp = client.get(f"{self.base_url}/api/tags")
                if resp.status_code == 200:
                    data = resp.json()
                    models = [m.get("name", "") for m in data.get("models", [])]
                    # Direct match or prefix match (e.g. qwen3:8b in qwen3:8b)
                    return any(target in m or m.startswith(target) for m in models)
                return False
        except Exception as e:
            logger.debug(f"Error checking model {target} in Ollama: {e}")
            return False

    async def a_is_available(self) -> bool:
        """Async check for LLM runtime availability."""
        if self.provider == "groq":
            if not self.groq_api_key:
                return False
            try:
                async with httpx.AsyncClient(timeout=3.0) as client:
                    resp = await client.get(f"{self.base_url}/models", headers=self._groq_headers())
                    return resp.status_code == 200
            except Exception:
                return False
        if not settings.OLLAMA_ENABLED:
            return False
        try:
            async with httpx.AsyncClient(timeout=3.0) as client:
                resp = await client.get(f"{self.base_url}/api/tags")
                return resp.status_code == 200
        except Exception:
            return False

    async def a_is_model_available(self, model_name: Optional[str] = None) -> bool:
        """Async check for target model availability in Ollama or Groq."""
        target = model_name or self.default_model
        if self.provider == "groq":
            if not self.groq_api_key:
                return False
            try:
                async with httpx.AsyncClient(timeout=3.0) as client:
                    resp = await client.get(f"{self.base_url}/models", headers=self._groq_headers())
                    if resp.status_code == 200:
                        models = [m.get("id", "") for m in resp.json().get("data", [])]
                        return target in models
                    return False
            except Exception:
                return False
        try:
            async with httpx.AsyncClient(timeout=3.0) as client:
                resp = await client.get(f"{self.base_url}/api/tags")
                if resp.status_code == 200:
                    data = resp.json()
                    models = [m.get("name", "") for m in data.get("models", [])]
                    return any(target in m or m.startswith(target) for m in models)
                return False
        except Exception:
            return False

    def chat_completion(
        self,
        messages: List[Dict[str, str]],
        model: Optional[str] = None,
        temperature: Optional[float] = None,
        max_tokens: Optional[int] = None,
        timeout: Optional[int] = None,
        format: Optional[Any] = None
    ) -> Dict[str, Any]:
        """
        Synchronous chat completion with local Ollama or Groq.
        """
        target_model = model or self.default_model
        target_temp = temperature if temperature is not None else settings.OLLAMA_TEMPERATURE
        target_max_tokens = max_tokens or max(settings.OLLAMA_MAX_TOKENS, 1024)
        req_timeout = timeout or self.timeout_seconds

        if self.provider == "groq":
            return self._groq_chat_completion(
                messages=messages,
                target_model=target_model,
                target_temp=target_temp,
                target_max_tokens=target_max_tokens,
                req_timeout=req_timeout,
                format=format,
            )

        payload: Dict[str, Any] = {
            "model": target_model,
            "messages": messages,
            "stream": False,
            "options": {
                "temperature": target_temp,
                "num_predict": target_max_tokens
            }
        }
        if format is not None:
            if hasattr(format, "model_json_schema"):
                payload["format"] = format.model_json_schema()
            else:
                payload["format"] = format

        start_t = time.time()
        timeout_config = httpx.Timeout(
            timeout=float(req_timeout),
            connect=3.0,
            read=float(req_timeout),
            write=10.0,
            pool=5.0
        )
        try:
            with httpx.Client(timeout=timeout_config) as client:
                resp = client.post(f"{self.base_url}/api/chat", json=payload)
                elapsed = time.time() - start_t

                if resp.status_code != 200:
                    logger.error(f"Ollama chat error HTTP {resp.status_code}: {resp.text}")
                    return {
                        "success": False,
                        "error_type": "http_error",
                        "error": f"HTTP {resp.status_code}: {resp.text}",
                        "content": None,
                        "latency_seconds": elapsed
                    }

                data = resp.json()
                msg = data.get("message", {})
                content = msg.get("content", "").strip()

                # Clean thinking tags if present
                if "<think>" in content and "</think>" in content:
                    parts = content.split("</think>", 1)
                    content = parts[1].strip()

                return {
                    "success": True,
                    "content": content,
                    "model": data.get("model", target_model),
                    "total_duration": data.get("total_duration"),
                    "eval_count": data.get("eval_count"),
                    "latency_seconds": elapsed
                }
        except httpx.TimeoutException:
            elapsed = time.time() - start_t
            logger.warning(f"Ollama inference timed out after {elapsed:.2f}s (limit: {req_timeout}s)")
            return {
                "success": False,
                "error_type": "timeout",
                "error": f"Inference timed out after {req_timeout}s",
                "content": None,
                "latency_seconds": elapsed
            }
        except httpx.ConnectError as e:
            elapsed = time.time() - start_t
            logger.warning(f"Could not connect to Ollama at {self.base_url}: {e}")
            return {
                "success": False,
                "error_type": "connection_refused",
                "error": f"Connection refused at {self.base_url}",
                "content": None,
                "latency_seconds": elapsed
            }
        except Exception as e:
            elapsed = time.time() - start_t
            logger.error(f"Unexpected error during Ollama invocation: {e}")
            return {
                "success": False,
                "error_type": "unspecified_error",
                "error": str(e),
                "content": None,
                "latency_seconds": elapsed
            }

    async def a_chat_completion(
        self,
        messages: List[Dict[str, str]],
        model: Optional[str] = None,
        temperature: Optional[float] = None,
        max_tokens: Optional[int] = None,
        timeout: Optional[int] = None,
        format: Optional[Any] = None
    ) -> Dict[str, Any]:
        """
        Asynchronous chat completion with local Ollama.
        """
        target_model = model or self.default_model
        target_temp = temperature if temperature is not None else settings.OLLAMA_TEMPERATURE
        target_max_tokens = max_tokens or max(settings.OLLAMA_MAX_TOKENS, 1024)
        req_timeout = timeout or self.timeout_seconds

        if self.provider == "groq":
            return await self._a_groq_chat_completion(
                messages=messages,
                target_model=target_model,
                target_temp=target_temp,
                target_max_tokens=target_max_tokens,
                req_timeout=req_timeout,
                format=format,
            )

        payload: Dict[str, Any] = {
            "model": target_model,
            "messages": messages,
            "stream": False,
            "options": {
                "temperature": target_temp,
                "num_predict": target_max_tokens
            }
        }
        if format is not None:
            if hasattr(format, "model_json_schema"):
                payload["format"] = format.model_json_schema()
            else:
                payload["format"] = format

        start_t = time.time()
        timeout_config = httpx.Timeout(
            timeout=float(req_timeout),
            connect=3.0,
            read=float(req_timeout),
            write=10.0,
            pool=5.0
        )
        try:
            async with httpx.AsyncClient(timeout=timeout_config) as client:
                resp = await client.post(f"{self.base_url}/api/chat", json=payload)
                elapsed = time.time() - start_t

                if resp.status_code != 200:
                    logger.error(f"Ollama async chat error HTTP {resp.status_code}: {resp.text}")
                    return {
                        "success": False,
                        "error_type": "http_error",
                        "error": f"HTTP {resp.status_code}: {resp.text}",
                        "content": None,
                        "latency_seconds": elapsed
                    }

                data = resp.json()
                msg = data.get("message", {})
                content = msg.get("content", "").strip()

                if "<think>" in content and "</think>" in content:
                    parts = content.split("</think>", 1)
                    content = parts[1].strip()

                return {
                    "success": True,
                    "content": content,
                    "model": data.get("model", target_model),
                    "total_duration": data.get("total_duration"),
                    "eval_count": data.get("eval_count"),
                    "latency_seconds": elapsed
                }
        except httpx.TimeoutException:
            elapsed = time.time() - start_t
            logger.warning(f"Ollama async inference timed out after {elapsed:.2f}s")
            return {
                "success": False,
                "error_type": "timeout",
                "error": f"Inference timed out after {req_timeout}s",
                "content": None,
                "latency_seconds": elapsed
            }
        except httpx.ConnectError as e:
            elapsed = time.time() - start_t
            return {
                "success": False,
                "error_type": "connection_refused",
                "error": f"Connection refused at {self.base_url}",
                "content": None,
                "latency_seconds": elapsed
            }
        except Exception as e:
            elapsed = time.time() - start_t
            return {
                "success": False,
                "error_type": "unspecified_error",
                "error": str(e),
                "content": None,
                "latency_seconds": elapsed
            }

    @staticmethod
    def _clean_think_tags(content: str) -> str:
        if "<think>" in content and "</think>" in content:
            return content.split("</think>", 1)[1].strip()
        return content

    def _build_groq_payload(
        self,
        messages: List[Dict[str, str]],
        target_model: str,
        target_temp: float,
        target_max_tokens: int,
        format: Optional[Any],
    ) -> Dict[str, Any]:
        payload: Dict[str, Any] = {
            "model": target_model,
            "messages": messages,
            "temperature": target_temp,
            "max_tokens": target_max_tokens,
        }
        if format is not None:
            payload["response_format"] = {"type": "json_object"}
        return payload

    def _groq_chat_completion(
        self,
        messages: List[Dict[str, str]],
        target_model: str,
        target_temp: float,
        target_max_tokens: int,
        req_timeout: int,
        format: Optional[Any],
    ) -> Dict[str, Any]:
        if not self.groq_api_key:
            return {
                "success": False,
                "error_type": "configuration_error",
                "error": "GROQ_API_KEY is not configured.",
                "content": None,
                "latency_seconds": 0.0,
            }
        payload = self._build_groq_payload(messages, target_model, target_temp, target_max_tokens, format)
        start_t = time.time()
        timeout_config = httpx.Timeout(timeout=float(req_timeout), connect=5.0, read=float(req_timeout))
        try:
            with httpx.Client(timeout=timeout_config) as client:
                resp = client.post(
                    f"{self.base_url}/chat/completions",
                    headers=self._groq_headers(),
                    json=payload,
                )
                elapsed = time.time() - start_t
                return self._parse_groq_response(resp, target_model, elapsed)
        except httpx.TimeoutException:
            elapsed = time.time() - start_t
            return {
                "success": False,
                "error_type": "timeout",
                "error": f"Groq inference timed out after {req_timeout}s",
                "content": None,
                "latency_seconds": elapsed,
            }
        except httpx.ConnectError as e:
            elapsed = time.time() - start_t
            return {
                "success": False,
                "error_type": "connection_refused",
                "error": f"Could not connect to Groq API: {e}",
                "content": None,
                "latency_seconds": elapsed,
            }
        except Exception as e:
            elapsed = time.time() - start_t
            return {
                "success": False,
                "error_type": "unspecified_error",
                "error": str(e),
                "content": None,
                "latency_seconds": elapsed,
            }

    async def _a_groq_chat_completion(
        self,
        messages: List[Dict[str, str]],
        target_model: str,
        target_temp: float,
        target_max_tokens: int,
        req_timeout: int,
        format: Optional[Any],
    ) -> Dict[str, Any]:
        if not self.groq_api_key:
            return {
                "success": False,
                "error_type": "configuration_error",
                "error": "GROQ_API_KEY is not configured.",
                "content": None,
                "latency_seconds": 0.0,
            }
        payload = self._build_groq_payload(messages, target_model, target_temp, target_max_tokens, format)
        start_t = time.time()
        timeout_config = httpx.Timeout(timeout=float(req_timeout), connect=5.0, read=float(req_timeout))
        try:
            async with httpx.AsyncClient(timeout=timeout_config) as client:
                resp = await client.post(
                    f"{self.base_url}/chat/completions",
                    headers=self._groq_headers(),
                    json=payload,
                )
                elapsed = time.time() - start_t
                return self._parse_groq_response(resp, target_model, elapsed)
        except httpx.TimeoutException:
            elapsed = time.time() - start_t
            return {
                "success": False,
                "error_type": "timeout",
                "error": f"Groq inference timed out after {req_timeout}s",
                "content": None,
                "latency_seconds": elapsed,
            }
        except httpx.ConnectError as e:
            elapsed = time.time() - start_t
            return {
                "success": False,
                "error_type": "connection_refused",
                "error": f"Could not connect to Groq API: {e}",
                "content": None,
                "latency_seconds": elapsed,
            }
        except Exception as e:
            elapsed = time.time() - start_t
            return {
                "success": False,
                "error_type": "unspecified_error",
                "error": str(e),
                "content": None,
                "latency_seconds": elapsed,
            }

    def _parse_groq_response(self, resp: httpx.Response, target_model: str, elapsed: float) -> Dict[str, Any]:
        if resp.status_code == 429:
            logger.warning("Groq API rate limit exceeded (HTTP 429)")
            return {
                "success": False,
                "error_type": "rate_limit",
                "error": "Groq free-tier rate limit exceeded (HTTP 429). Please retry shortly.",
                "content": None,
                "latency_seconds": elapsed,
            }
        if resp.status_code != 200:
            logger.error("Groq chat error HTTP %s: %s", resp.status_code, resp.text[:300])
            return {
                "success": False,
                "error_type": "http_error",
                "error": f"HTTP {resp.status_code}: {resp.text[:300]}",
                "content": None,
                "latency_seconds": elapsed,
            }
        data = resp.json()
        choices = data.get("choices") or []
        raw_content = (choices[0].get("message", {}).get("content", "") if choices else "").strip()
        content = self._clean_think_tags(raw_content)
        usage = data.get("usage") or {}
        return {
            "success": True,
            "content": content,
            "model": data.get("model", target_model),
            "eval_count": usage.get("completion_tokens"),
            "latency_seconds": elapsed,
        }
