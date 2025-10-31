FROM tomcat:9.0.109

COPY target/myweb*.war /usr/local/tomcat/webapps/myweb.war

