import Config

config :auth0_client,
  domain: "brighterlink.auth0.com",
  mgmt_token: "TESTTOKEN",
  http_opts: [plug: {Req.Test, Auth0Client.Api}, retry: false]
