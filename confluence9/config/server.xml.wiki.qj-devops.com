<?xml version="1.0" encoding="utf-8"?>
<!--
  Production behind nginx https://wiki.qj-devops.com
  Enable: cp config/server.xml.wiki.qj-devops.com config/server.xml.local
          echo CONFLUENCE_SERVER_XML=config/server.xml.local >> .env
          docker compose up -d confluence
  Only after nginx upstream points to 10.173.32.9:8090 / :8091.
-->
<Server port="8000" shutdown="SHUTDOWN">
    <Service name="Tomcat-Standalone">
        <Connector port="8090" connectionTimeout="20000" redirectPort="8443"
                   maxThreads="48" maxPostSize="16777216" minSpareThreads="10"
                   enableLookups="false" acceptCount="10" URIEncoding="UTF-8"
                   protocol="org.apache.coyote.http11.Http11NioProtocol"
                   scheme="https" secure="true"
                   proxyName="wiki.qj-devops.com" proxyPort="443"/>

        <Engine name="Standalone" defaultHost="localhost">
            <Host name="localhost" appBase="webapps" unpackWARs="true" autoDeploy="false" startStopThreads="4">
                <Context path="" docBase="../confluence" reloadable="false" useHttpOnly="true">
                    <Manager pathname=""/>
                    <Valve className="org.apache.catalina.valves.StuckThreadDetectionValve" threshold="60"/>
                    <Valve className="org.apache.catalina.valves.AccessLogValve"
                           directory="logs"
                           maxDays="30"
                           pattern="%t %{X-AUSERNAME}o %I %h %r %s %Dms %b %{Referer}i %{User-Agent}i"
                           prefix="conf_access_log"
                           requestAttributesEnabled="true"
                           rotatable="true"
                           suffix=".log"/>
                    <Valve className="org.apache.catalina.valves.RemoteIpValve"
                           remoteIpHeader="x-forwarded-for"
                           protocolHeader="x-forwarded-proto"
                           hostHeader="x-forwarded-host"
                           portHeader="x-forwarded-port"
                           protocolHeaderHttpsValue="https"
                           httpsServerPort="443"/>
                </Context>

                <Context path="${confluence.context.path}/synchrony-proxy" docBase="../synchrony-proxy"
                         reloadable="false" useHttpOnly="true">
                    <Valve className="org.apache.catalina.valves.StuckThreadDetectionValve" threshold="60"/>
                </Context>
            </Host>
        </Engine>
    </Service>
</Server>
