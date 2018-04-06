if Code.ensure_loaded?(HTTPotion) do
  defmodule CookieJar.HTTPotion do
    @actions ~w(
      get head options delete post put patch
      get! head! options! delete! post! put! patch!
    )a

    @moduledoc ~s"""
    Use this module instead of HTTPotion, use jar as the first argument in all
    function calls, i.e. #{inspect(@actions)}
    """

    import CookieJar.SpecUtils, only: [httpotion_spec: 1]

    for action <- @actions do
      [
        Code.eval_quoted(httpotion_spec(action), [], __ENV__),
        def unquote(action)(jar, url, options \\ []) do
          headers = add_jar_cookies(jar, options[:headers])
          result = HTTPotion.unquote(action)(url, Keyword.put(options, :headers, headers))
          update_jar_cookies(jar, result)
        end
      ]
    end

    defp add_jar_cookies(jar, nil), do: add_jar_cookies(jar, [])

    defp add_jar_cookies(jar, headers) do
      jar_cookies = CookieJar.label(jar)

      headers
      |> Enum.into(%{})
      |> Map.update(:Cookie, jar_cookies, fn user_cookies ->
        "#{user_cookies}; #{jar_cookies}"
      end)
      |> Enum.into([])
    end

    defp update_jar_cookies(jar, %HTTPotion.Response{headers: headers} = response) do
      do_update_jar_cookies(jar, headers)
      response
    end

    defp update_jar_cookies(_jar, %HTTPotion.ErrorResponse{} = error), do: error

    defp do_update_jar_cookies(jar, %HTTPotion.Headers{hdrs: headers}) do
      response_cookies = Map.get(headers, "set-cookie", []) |> List.wrap()

      cookies =
        Enum.reduce(response_cookies, %{}, fn cookie, cookies ->
          [key_value_string | _rest] = String.split(cookie, "; ")
          [key, value] = String.split(key_value_string, "=", parts: 2)
          Map.put(cookies, key, value)
        end)

      CookieJar.pour(jar, cookies)
    end
  end
end
