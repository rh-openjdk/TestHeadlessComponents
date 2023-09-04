import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.TimeUnit;


public class SwingTestUtils {
    public static final String NEW_COMPONENTS = "New components";
    public static final String COMPONENT_PREPARED = "Component prepared";
    public static final String UNEXPECTED_EXCEPTION = "This is unexpected exception.";
    public static final String EXPECTED_ERROR_STRING = "Expected error occured. This is ok.";
    private static TestArgumentParser parser;

    public SwingTestUtils(TestArgumentParser parser){
	this.parser = parser;
    }

    public static boolean printMessageErrorFound(Error e) {
        System.err.println("Unexpected error. Print the error, mark the test as fail and die later.");
        e.printStackTrace();
        return true;
    }

    public boolean testComponents() throws InterruptedException{
	boolean err = false;
	List<AbstractComponent> components = new ArrayList<>();
	System.out.println(NEW_COMPONENTS);
	if(parser.testJreHeadlessCompatible()){
	    components.addAll(prepareJreHeadlessCompatibleComponents());
	}
	if(parser.testJreHeadlessIncompatible()){
	    components.addAll(prepareJreHeadlessIncompatibleComponents());
	}
	System.out.println(COMPONENT_PREPARED);
	for(AbstractComponent component : components){
            err = component.testComponent(parser) || err;
        }
        return err;
    }

    protected static List<AbstractComponent> prepareJreHeadlessCompatibleComponents() {
        AbstractComponent checkbox = new JCheckBoxExample();
        AbstractComponent button = new JButtonExample();
        AbstractComponent comboBox = new JComboBoxExample();
        AbstractComponent label = new JLabelExample();
        ArrayList<AbstractComponent> components = new ArrayList<>();
        components.add(comboBox);
        components.add(button);
        components.add(label);
        components.add(checkbox);
        return components;
    }

    protected static List<AbstractComponent> prepareJreHeadlessIncompatibleComponents() {
	AbstractComponent frame = new JFrameExample();
	AbstractComponent dialog = new JDialogExample();
        ArrayList<AbstractComponent> components = new ArrayList<>();
	components.add(frame);
	components.add(dialog);
	return components;
    }


    protected static void createComponent(AbstractComponent component) throws Exception {
        final AbstractComponent comp = component;
        comp.startCreation();
        TimeUnit.SECONDS.sleep(5);
        System.out.println("Successfully created component!");
    }
}
