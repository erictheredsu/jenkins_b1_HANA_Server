package com.sap.businessone.jmeter.functions;

import java.util.Collection;
import java.util.LinkedList;
import java.util.List;
import java.util.UUID;

import org.apache.jmeter.engine.util.CompoundVariable;
import org.apache.jmeter.functions.AbstractFunction;
import org.apache.jmeter.functions.InvalidVariableException;
import org.apache.jmeter.samplers.SampleResult;
import org.apache.jmeter.samplers.Sampler;

public class DummyClass extends AbstractFunction {

    private static final List<String> desc = new LinkedList<String>();

    @Override
    public List<String> getArgumentDesc() {
        return desc;
    }

    @Override
    public String execute(SampleResult previousResult, Sampler currentSampler) throws InvalidVariableException {
        return "Dummy_" + UUID.randomUUID().toString().replace('-', '_');
    }

    @Override
    public String getReferenceKey() {
        return "__DummyClass";
    }

    @Override
    public void setParameters(Collection<CompoundVariable> arg0) throws InvalidVariableException {
        // nothing to do
    }

}
