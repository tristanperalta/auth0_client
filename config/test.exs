import Config

config :auth0_ex,
  domain: "brighterlink.auth0.com",
  mgmt_token: "TESTTOKEN",
  http_opts: [plug: {Req.Test, Auth0Ex.Api}, retry: false]
