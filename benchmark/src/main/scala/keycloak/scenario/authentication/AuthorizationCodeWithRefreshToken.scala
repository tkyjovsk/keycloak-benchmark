package keycloak.scenario.authentication

import keycloak.scenario.{CommonSimulation, KeycloakScenarioBuilder}

class AuthorizationCodeWithRefreshToken extends CommonSimulation {

  setUp("Authentication - Authorization Code Username/Password", new KeycloakScenarioBuilder()
    .openLoginPage(true)
 
    .userThinkPause()
    .loginUsernamePassword()
    .exchangeCode()

    .userThinkPause()
    .refreshToken()

    .userThinkPause()
    .refreshToken()

    .userThinkPause()
    .refreshToken()

    .userThinkPause()
    .logout(true))

}