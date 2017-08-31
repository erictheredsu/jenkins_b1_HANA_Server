package com.sap.businessone.jmeter.functions;

import static org.junit.Assert.*;

import org.junit.Test;

public class DummyClassTest {

    @Test
    public void test() {
        try {
            DummyClass c = new DummyClass();
            String s = c.execute();
            System.out.println(s);
        } catch (Exception e) {
            fail(e.getMessage());
        }
    }

}
