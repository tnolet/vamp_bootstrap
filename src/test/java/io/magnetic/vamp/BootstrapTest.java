package io.magnetic.vamp;

import org.junit.After;
import org.junit.Before;
import org.junit.Test;

import static org.junit.Assert.*;

public class BootstrapTest {

    @Before
    public void setUp() throws Exception {

        String public_address = new String("127.0.0.1");

    }

    @After
    public void tearDown() throws Exception {

    }

    @Test
    public void testDisplaySyntax() throws Exception {

        Bootstrap bootstrap = new Bootstrap(new String[]{""});
        assertNotNull(bootstrap.displaySyntax());

    }
}