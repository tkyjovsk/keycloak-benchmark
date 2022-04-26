package keycloak.scenario.authentication

import keycloak.scenario.{CommonSimulation, KeycloakScenarioBuilder}


class ClientCredentialsWithRefreshToken extends CommonSimulation {

  setUp("Authentication - Client Credentials with Token Refresh", new KeycloakScenarioBuilder()
    .clientCredentialsGrant()
    .userThinkPause()
    .refreshToken()
    .userThinkPause()
    .clientLogout()
  )

}

