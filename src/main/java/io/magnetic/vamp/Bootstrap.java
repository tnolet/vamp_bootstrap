/*
   Bootstrap configures Hazelcast for clustering in Docker
   It performs two tasks:

   1) Setup Hazelcast for routing between Docker instances on different hosts
   2) Setup the Vertx event bus for routing between verticles running in these Docker instances

   This code is based almost entirely on the standard Vertx Starter class and the extra commit remarks regarding
   the programmatic configuration of the event bus, please see:

   https://github.com/eclipse/vert.x/blob/master/vertx-platform/src/main/java/org/vertx/java/platform/impl/cli/Starter.java
   https://github.com/eclipse/vert.x/pull/777
*/

package io.magnetic.vamp;

import org.vertx.java.core.json.JsonObject;
import org.vertx.java.core.logging.Logger;
import org.vertx.java.core.logging.impl.LoggerFactory;
import org.vertx.java.platform.*;
import org.vertx.java.core.*;
import com.hazelcast.config.*;
import org.vertx.java.platform.impl.Args;
import org.vertx.java.spi.cluster.impl.hazelcast.*;

import java.net.MalformedURLException;
import java.net.URL;
import java.util.ArrayList;
import java.util.List;


public class Bootstrap {

    private static final Logger log = LoggerFactory.getLogger(Bootstrap.class);

    public static void main(String[] args) {

        new Bootstrap(args);
    }

    private Bootstrap(String[] sargs) {

        Args args = new Args(sargs);
        sargs = removeOptions(sargs);

        log.info("Starting Vamp Bootstrap...");

        if (sargs.length == 0) {
            displaySyntax();
        } else {
            String command = sargs[0].toLowerCase();
            if ("version".equals(command)) {
                log.info("Vamp Bootstrap 0.1");
            } else {
                if (sargs.length < 2) {
                    displaySyntax();
                } else {
                    switch (command) {
                        case "run":
                           runVertx(args);
                            break;
                        default:
                            displaySyntax();
                    }
                }
            }
        }
    }

    private void runVertx(Args args) {

        // Hazelcast properties
        String hazelcastPublicAddress = args.map.get("-public_address");
       // String hazelcastLocalAddress = args.map.get("-local_address");
        String hazelcastRemoteAddress = args.map.get("-remote_address");
        int hazelcastPort = Integer.parseInt(args.map.get("-cluster_port"));

        // Vertx properties
        String vertxVerticle = args.map.get("-verticle"); //name of file
        String vertxClassPath = args.map.get("-classpath"); //directory

        String vertxPublicHost = args.map.get("-public_address");
        Integer vertxPublicPort = Integer.parseInt(args.map.get("-event_bus_port"));
        String vertxClusterHost = args.map.get("-local_address");
        int vertxClusterPort = Integer.parseInt(args.map.get("-event_bus_port"));

        System.setProperty("vertx.cluster.public.host", vertxPublicHost);
        System.setProperty("vertx.cluster.public.port", Integer.toString(vertxPublicPort));

//        Create new config objects for Hazelcast
        Config cfg = new Config();
        ProgrammableClusterManagerFactory.setConfig(cfg);
        System.setProperty("vertx.clusterManagerFactory", ProgrammableClusterManagerFactory.class.getName());

        NetworkConfig network = cfg.getNetworkConfig();
        network.setPort(hazelcastPort);
        network.setPortAutoIncrement(false);

        network.setPublicAddress(hazelcastPublicAddress);

//        Interfaces interfaces = new Interfaces();
//        interfaces.addInterface("127.0.0.1");
//        network.setInterfaces(interfaces);

        Join join = network.getJoin();
        join.getMulticastConfig().setEnabled(false);
        join.getTcpIpConfig().addMember(hazelcastRemoteAddress).setEnabled(true);

        PlatformManager pm = PlatformLocator.factory.createPlatformManager(vertxClusterPort, vertxClusterHost);

//        Set up the configuration object
        JsonObject conf = new JsonObject();

//        Set the initializing verticle. This is the verticle that will spin up all other verticles
        URL classpath_location = null;
        try {
            classpath_location = new URL("file:///" + vertxClassPath);
        } catch (MalformedURLException e) {
            e.printStackTrace();
        }
        URL[] classpath = new URL[]{classpath_location};

        pm.deployVerticle(vertxVerticle, conf, classpath, 1, null, new AsyncResultHandler<String>() {
            public void handle(AsyncResult<String> asyncResult) {
                if (asyncResult.succeeded()) {
                    System.out.println("Deployment ID is " + asyncResult.result());
                } else {
                    asyncResult.cause().printStackTrace();
                }
            }
        });
    }


    private String[] removeOptions(String[] args) {
        List<String> munged = new ArrayList<>();
        for (String arg: args) {
            if (!arg.startsWith("-")) {
                munged.add(arg);
            }
        }
        return munged.toArray(new String[munged.size()]);
    }

    private static void displaySyntax() {

        String usage =
                "                                      \n"+
                " | |  / /___ _____ ___  ____          \n"+
                " | | / / __ `/ __ `__ \\/ __ \\       \n"+
                " | |/ / /_/ / / / / / / /_/ /         \n"+
                " |___/\\__,_/_/ /_/ /_/ .___/         \n"+
                "                    /_/               \n"+
                " vamp run [-options]                                                                        \n" +
                        "        run a bootstrapper that configures and connects up Hazelcast           \n" +
                        "        and the Vertx event bus for usage in Docker containers.                \n" +
                        "        required options are:                                                  \n" +
                        "        -public_address        specifies the public address of the host on     \n" +
                        "                               which Docker is running. This is the address    \n" +
                        "                               other hosts will connect to.                    \n" +
                        "                                                                               \n" +
                        "        -local_address         specifies the local address inside the Docker   \n" +
                        "                               container, i.e. eth0.                           \n" +
                        "                                                                               \n" +
                        "        -remote_address        specifies the public address of the remote      \n" +
                        "                               host we are trying to connect to.               \n" +
                        "                                                                               \n" +
                        "        -cluster_port          specifies the port for the hazelcast cluster    \n" +
                        "                                                                               \n" +
                        "        -event_bus_port        specifies the port for the event bus            \n" +
                        "                                                                               \n" +
                        "        -verticle              specifies the verticle to run                   \n" +
                        "                                                                               \n" +
                        "        -classpath             specifies the classpath                         \n" +
                        "                                                                               \n" +
                        "                                                                               \n";

        log.info(usage);
    }
}